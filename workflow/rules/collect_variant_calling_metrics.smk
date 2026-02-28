rule collect_variant_calling_metrics:
  input:
    signal=rules.gather_final_vcf.output.signal,
    dbsnp_vcf=config["resources"].get("dbsnp_vcf"),
    reference_dict=config["resources"].get("reference_dict"),
    reference_fasta_index=config["resources"].get("reference_fasta_index"),
    eval_interval_list=config["resources"].get("eval_interval_list"),
  output:
    signal=touch("results/collect_variant_calling_metrics.ok"),
  params:
    tmp_dir=config["params"].get("tmp_dir"),
  container: config["environments"].get("custom")
  log: "logs/collect_variant_calling_metrics.log"
  shell:
    """
    exec >> {log} 2>&1

    METRICS_TMP=$(mktemp -d -p {params.tmp_dir} variant_calling_metrics.XXXXXX)
    trap "rm -rf $METRICS_TMP" EXIT

    TMP_DBSNP_VCF_BGZ="$METRICS_TMP/dbsnp.vcf.gz"
    TMP_DBSNP_VCF_REHEADER="$METRICS_TMP/dbsnp.reheader.vcf.gz"
    
    bgzip -@ {resources.threads} -c {input.dbsnp_vcf} > $TMP_DBSNP_VCF_BGZ
    bcftools index $TMP_DBSNP_VCF_BGZ
    bcftools reheader -f {input.reference_fasta_index} -o $TMP_DBSNP_VCF_REHEADER $TMP_DBSNP_VCF_BGZ
    bcftools index -t $TMP_DBSNP_VCF_REHEADER

    java -Xms6000m -Xmx{resources.mem_mb}m -jar /usr/bin/picard.jar \
      CollectVariantCallingMetrics \
        --INPUT results/{CALLSET_NAME}.final.vcf.gz \
        --DBSNP $TMP_DBSNP_VCF_REHEADER \
        --SEQUENCE_DICTIONARY {input.reference_dict} \
        --OUTPUT results/{CALLSET_NAME} \
        --THREAD_COUNT {resources.threads} \
        --TARGET_INTERVALS {input.eval_interval_list} \
    """
