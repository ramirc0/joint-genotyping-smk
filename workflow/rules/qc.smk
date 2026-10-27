# Callset metrics against dbSNP.


rule collect_variant_calling_metrics:
    input:
        **REFERENCE,
        vcf=f"{OUTDIR}/{CALLSET}.final.vcf.gz",
        dbsnp_vcf=REFS["dbsnp_vcf"],
        eval_interval_list=REFS["eval_interval_list"],
    output:
        detail=f"{OUTDIR}/{CALLSET}.variant_calling_detail_metrics",
        summary=f"{OUTDIR}/{CALLSET}.variant_calling_summary_metrics",
    params:
        tmp_dir=lambda w: config["tmp_dir"],
        prefix=f"{OUTDIR}/{CALLSET}",
    log:
        f"{LOGDIR}/collect_variant_calling_metrics.txt",
    benchmark:
        f"{BENCHDIR}/collect_variant_calling_metrics.tsv",
    software:
        SOFTWARE_ENV
    shell:
        r"""
        exec &> >(tee {log:q})

        METRICS_TMP=$(mktemp -d -p {params.tmp_dir:q} variant_calling_metrics.XXXXXX)
        trap "rm -rf $METRICS_TMP" EXIT

        TMP_DBSNP_VCF_BGZ="$METRICS_TMP/dbsnp.vcf.gz"
        TMP_DBSNP_VCF_REHEADER="$METRICS_TMP/dbsnp.reheader.vcf.gz"

        bgzip -@ {threads:q} -c {input.dbsnp_vcf:q} > "$TMP_DBSNP_VCF_BGZ"
        bcftools index "$TMP_DBSNP_VCF_BGZ"
        bcftools reheader -f {input.fasta_index:q} -o "$TMP_DBSNP_VCF_REHEADER" "$TMP_DBSNP_VCF_BGZ"
        bcftools index -t "$TMP_DBSNP_VCF_REHEADER"

        picard -Xms6000m -Xmx$(({resources.mem_mb} - 3000))m \
            CollectVariantCallingMetrics \
            --INPUT {input.vcf:q} \
            --DBSNP "$TMP_DBSNP_VCF_REHEADER" \
            --SEQUENCE_DICTIONARY {input.fasta_dict:q} \
            --OUTPUT {params.prefix:q} \
            --THREAD_COUNT {threads:q} \
            --TARGET_INTERVALS {input.eval_interval_list:q}
        """
