# Joint calling per scatter, from the gVCFs to hard-filtered VCFs.


rule split_interval_list:
    input:
        **REFERENCE,
        unpadded_interval_list=REFS["unpadded_interval_list"],
    output:
        expand(SCATTERED_INTERVAL_LIST, scatter=SCATTERS),
    params:
        scatter_dir=f"{OUTDIR}/scatter_dir",
        scatter_count=lambda w: config["scatter_count"],
        scatter_mode=lambda w: config["scatter_mode"],
        digits=SCATTER_DIGITS,
    log:
        f"{LOGDIR}/split_interval_list.txt",
    benchmark:
        f"{BENCHDIR}/split_interval_list.tsv",
    software:
        GATK_ENV
    shell:
        r"""
        exec &> >(tee {log:q})

        gatk --java-options "-Xms3000m -Xmx{resources.mem_mb}m" SplitIntervals \
            -L {input.unpadded_interval_list:q} \
            -O {params.scatter_dir:q} \
            -scatter {params.scatter_count:q} \
            -R {input.fasta:q} \
            -mode {params.scatter_mode:q} \
            --interval-file-num-digits {params.digits:q} \
            --interval-merging-rule OVERLAPPING_ONLY

        sync {output:q}
        """


# GenomicsDB's native memory lives outside the JVM heap, hence the 10 GB of headroom.
rule import_gvcfs:
    input:
        sample_map=SAMPLE_MAP,
        interval_list=SCATTERED_INTERVAL_LIST,
    output:
        workspace=directory(f"{OUTDIR}/import_gvcfs/{{scatter}}"),
        tar=f"{OUTDIR}/import_gvcfs/{{scatter}}.tar",
    params:
        tmp_dir=lambda w: config["tmp_dir"],
        batch_size=lambda w: config["batch_size"],
    log:
        f"{LOGDIR}/import_gvcfs/{{scatter}}.txt",
    benchmark:
        f"{BENCHDIR}/import_gvcfs/{{scatter}}.tsv",
    software:
        GATK_ENV
    shell:
        r"""
        exec &> >(tee {log:q})

        gatk --java-options "-Xms8000m -Xmx$(({resources.mem_mb} - 10000))m" \
            GenomicsDBImport \
            --tmp-dir {params.tmp_dir:q} \
            --genomicsdb-workspace-path {output.workspace:q} \
            --batch-size {params.batch_size:q} \
            -L {input.interval_list:q} \
            --sample-name-map {input.sample_map:q} \
            --reader-threads {threads:q} \
            --merge-input-intervals \
            --consolidate

        tar -cvf {output.tar:q} {output.workspace:q}

        sync {output:q}
        """


rule genotype_gvcfs:
    input:
        **REFERENCE,
        workspace=f"{OUTDIR}/import_gvcfs/{{scatter}}",
        interval_list=SCATTERED_INTERVAL_LIST,
        dbsnp_vcf=REFS["dbsnp_vcf"],
    output:
        vcf=f"{OUTDIR}/genotype_gvcfs/{CALLSET}.{{scatter}}.vcf.gz",
        tbi=f"{OUTDIR}/genotype_gvcfs/{CALLSET}.{{scatter}}.vcf.gz.tbi",
    params:
        tmp_dir=lambda w: config["tmp_dir"],
    log:
        f"{LOGDIR}/genotype_gvcfs/{{scatter}}.txt",
    benchmark:
        f"{BENCHDIR}/genotype_gvcfs/{{scatter}}.tsv",
    software:
        GATK_ENV
    shell:
        r"""
        exec &> >(tee {log:q})

        gatk --java-options "-Xms8000m -Xmx{resources.mem_mb}m" \
            GenotypeGVCFs \
            --tmp-dir {params.tmp_dir:q} \
            -R {input.fasta:q} \
            -O {output.vcf:q} \
            -D {input.dbsnp_vcf:q} \
            -G StandardAnnotation \
            -G AS_StandardAnnotation \
            --only-output-calls-starting-in-intervals \
            -V gendb://{input.workspace:q} \
            -L {input.interval_list:q} \
            --merge-input-intervals

        sync {output:q}
        """


rule hard_filter:
    input:
        f"{OUTDIR}/genotype_gvcfs/{CALLSET}.{{scatter}}.vcf.gz",
    output:
        vcf=f"{OUTDIR}/hard_filter/{CALLSET}.{{scatter}}.variant_filtered.vcf.gz",
        tbi=f"{OUTDIR}/hard_filter/{CALLSET}.{{scatter}}.variant_filtered.vcf.gz.tbi",
        sites_only_vcf=f"{OUTDIR}/hard_filter/{CALLSET}.{{scatter}}.sites_only.variant_filtered.vcf.gz",
        sites_only_tbi=f"{OUTDIR}/hard_filter/{CALLSET}.{{scatter}}.sites_only.variant_filtered.vcf.gz.tbi",
    params:
        tmp_dir=lambda w: config["tmp_dir"],
        excess_het_threshold=lambda w: config["excess_het_threshold"],
    log:
        f"{LOGDIR}/hard_filter/{{scatter}}.txt",
    benchmark:
        f"{BENCHDIR}/hard_filter/{{scatter}}.tsv",
    software:
        GATK_ENV
    shell:
        r"""
        exec &> >(tee {log:q})

        gatk --java-options "-Xms3000m -Xmx{resources.mem_mb}m" \
            VariantFiltration \
            --tmp-dir {params.tmp_dir:q} \
            --filter-expression "ExcessHet > {params.excess_het_threshold}" \
            --filter-name ExcessHet \
            -O {output.vcf:q} \
            -V {input:q}

        gatk --java-options "-Xms3000m -Xmx{resources.mem_mb}m" \
            MakeSitesOnlyVcf \
            --TMP_DIR {params.tmp_dir:q} \
            -I {output.vcf:q} \
            -O {output.sites_only_vcf:q}

        sync {output:q}
        """


rule gather_sites_only_vcfs:
    input:
        expand(
            f"{OUTDIR}/hard_filter/{CALLSET}.{{scatter}}.sites_only.variant_filtered.vcf.gz",
            scatter=SCATTERS,
        ),
    output:
        vcf=f"{OUTDIR}/{CALLSET}.sites_only.vcf.gz",
        tbi=f"{OUTDIR}/{CALLSET}.sites_only.vcf.gz.tbi",
    params:
        tmp_dir=lambda w: config["tmp_dir"],
        vcfs=lambda w, input: repeat_flag("--input", input),
    log:
        f"{LOGDIR}/gather_sites_only_vcfs.txt",
    benchmark:
        f"{BENCHDIR}/gather_sites_only_vcfs.tsv",
    software:
        GATK_ENV
    shell:
        r"""
        exec &> >(tee {log:q})

        gatk --java-options "-Xms6000m -Xmx{resources.mem_mb}m" \
            GatherVcfsCloud \
            --tmp-dir {params.tmp_dir:q} \
            --ignore-safety-checks \
            --gather-type BLOCK \
            {params.vcfs:q} \
            --output {output.vcf:q}

        tabix {output.vcf:q}

        sync {output:q}
        """
