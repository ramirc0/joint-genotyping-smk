#!/usr/bin/env bash
# Builds this directory's inputs: chr20:1-347695 of the 100 1000 Genomes gVCFs from the
# wgs-smk run, plus resource subsets, all on a toy contig "chr20" of that length.
# Ran once, from the repo root:
#   pixi exec -c conda-forge -c bioconda -s samtools==1.24 -s bcftools==1.24 -s gatk4==4.6.2.0 \
#     bash .tests/integration/make_test_data.sh
set -euo pipefail

GVCFS=/home/ramirezc/Projects/wgs-smk/main/results/1000g-representative-100
PANEL=/data/zusers/ramirezc/static/hg38/reads/1000G-30x/representative-100.tsv
GENOME=/data/zusers/ramirezc/static/hg38/genome/GRCh38_no_alt_analysis_set_GCA_000001405.15.fasta
BROAD=/data/zusers/ramirezc/static/hg38/broad-references/v0
WINDOW=chr20:1-347695
LENGTH=347695

cd "$(dirname "$0")"
mkdir -p config resources/gvcfs

# Swaps in the toy contig line, clamps reference blocks to the window
# and drops records that end past it.
to_toy() {
    awk -v len="$LENGTH" '
        BEGIN { FS = OFS = "\t" }
        /^##contig=/ { next }
        /^#CHROM/ { print "##contig=<ID=chr20,length=" len ">" }
        /^#/ { print; next }
        match($8, /(^|;)END=[0-9]+/) {
            end = substr($8, RSTART, RLENGTH)
            sub(/.*END=/, "", end)
            if (end + 0 > len)
                $8 = substr($8, 1, RSTART - 1) (RSTART > 1 ? ";" : "") "END=" len substr($8, RSTART + RLENGTH)
        }
        $2 + length($4) - 1 <= len { print }
    '
}

samtools faidx "$GENOME" "$WINDOW" | sed '1s/.*/>chr20/' > resources/chr20_toy.fasta
samtools faidx resources/chr20_toy.fasta
samtools dict -u chr20_toy.fasta -o resources/chr20_toy.dict resources/chr20_toy.fasta

tail -n +2 "$PANEL" | cut -f1 | sort | while read -r sample; do
    gvcf="resources/gvcfs/$sample.rb.g.vcf.gz"
    bcftools view --no-version -r "$WINDOW" "$GVCFS/$sample/reblock/$sample.rb.g.vcf.gz" \
        | to_toy | bgzip -l 9 > "$gvcf"
    tabix -p vcf "$gvcf"
    printf '%s\t%s\n' "$sample" "$gvcf"
done > config/sample_map.tsv

for name in hapmap_3.3 1000G_omni2.5 1000G_phase1.snps.high_confidence Mills_and_1000G_gold_standard.indels; do
    vcf="resources/$name.chr20_toy.vcf.gz"
    bcftools view --no-version -G -r "$WINDOW" "$BROAD/$name.hg38.vcf.gz" \
        | bcftools annotate --no-version -x INFO | to_toy | bgzip -l 9 > "$vcf"
    tabix -p vcf "$vcf"
done

# Plain, as in production. The metrics rule bgzips it itself.
bcftools view --no-version -r "$WINDOW" "$BROAD/Homo_sapiens_assembly38.dbsnp138.vcf.gz" \
    | bcftools annotate --no-version -x INFO | to_toy > resources/dbsnp138.chr20_toy.vcf
gatk IndexFeatureFile -I resources/dbsnp138.chr20_toy.vcf

{
    cat resources/chr20_toy.dict
    awk -v len="$LENGTH" 'BEGIN { FS = OFS = "\t" } $1 == "chr20" && $2 <= len { if ($3 > len) $3 = len; print }' \
        "$BROAD/wgs_evaluation_regions.hg38.interval_list"
} > resources/wgs_evaluation_regions.chr20_toy.interval_list

awk -F '[:-]' -v len="$LENGTH" '$1 == "chr20" && $3 <= len' "$BROAD/hg38.even.handcurated.20k.intervals" \
    > resources/hg38.even.handcurated.20k.chr20_toy.intervals

# Same checks as wgs-smk's validate_gvcf, over the window's calling regions.
for gvcf in resources/gvcfs/*.rb.g.vcf.gz; do
    gatk ValidateVariants \
        -V "$gvcf" \
        -R resources/chr20_toy.fasta \
        -L chr20:60001-63215 \
        -L chr20:63841-347695 \
        -gvcf \
        --validation-type-to-exclude ALLELES \
        --dbsnp resources/dbsnp138.chr20_toy.vcf \
        --no-overlaps
done
