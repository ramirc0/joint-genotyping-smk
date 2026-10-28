# Callset metrics against dbSNP.


# Picard needs the dbSNP contig lines to equal the reference dictionary.
rule prepare_dbsnp:
    input:
        dbsnp_vcf=REFS["dbsnp_vcf"],
        fasta_index=REFERENCE["fasta_index"],
    output:
        vcf=f"{OUTDIR}/dbsnp.vcf.gz",
        tbi=f"{OUTDIR}/dbsnp.vcf.gz.tbi",
    log:
        f"{LOGDIR}/prepare_dbsnp.txt",
    benchmark:
        f"{BENCHDIR}/prepare_dbsnp.tsv",
    software:
        SOFTWARE_ENV
    shell:
        r"""
        exec &> >(tee {log:q})

        bcftools reheader -f {input.fasta_index:q} {input.dbsnp_vcf:q} \
            | bgzip -@ {threads:q} -c > {output.vcf:q}
        tabix -p vcf {output.vcf:q}

        sync {output:q}
        """


rule collect_variant_calling_metrics:
    input:
        **REFERENCE,
        vcf=f"{OUTDIR}/{CALLSET}.final.vcf.gz",
        dbsnp_vcf=f"{OUTDIR}/dbsnp.vcf.gz",
        eval_interval_list=REFS["eval_interval_list"],
    output:
        detail=f"{OUTDIR}/{CALLSET}.variant_calling_detail_metrics",
        summary=f"{OUTDIR}/{CALLSET}.variant_calling_summary_metrics",
    params:
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

        picard -Xms6000m -Xmx$(({resources.mem_mb} - 3000))m \
            CollectVariantCallingMetrics \
            --INPUT {input.vcf:q} \
            --DBSNP {input.dbsnp_vcf:q} \
            --SEQUENCE_DICTIONARY {input.fasta_dict:q} \
            --OUTPUT {params.prefix:q} \
            --THREAD_COUNT {threads:q} \
            --TARGET_INTERVALS {input.eval_interval_list:q}

        sync {output:q}
        """
