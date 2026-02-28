rule hard_filter:
  input:
    singal=rules.genotype_gvcfs.output.singal,
  output:
    singal=touch("results/hard_filter/{scatter}.ok"),
  params:
    tmp_dir=config["params"].get("tmp_dir"),
    excess_het_threshold=config["params"].get("excess_het_threshold"),
  container: config["environments"].get("gatk")
  log: "logs/hard_filter/{scatter}.log"
  shell:
    """
    exec >> {log} 2>&1

    gatk --java-options "-Xms3000m -Xmx{resources.mem_mb}m" \
      VariantFiltration \
      --tmp-dir {params.tmp_dir} \
      --filter-expression "ExcessHet > {params.excess_het_threshold}" \
      --filter-name ExcessHet \
      -O results/hard_filter/{CALLSET_NAME}.{wildcards.scatter}.variant_filtered.vcf.gz \
      -V results/genotype_gvcfs/{CALLSET_NAME}.{wildcards.scatter}.vcf.gz

    gatk --java-options "-Xms3000m -Xmx{resources.mem_mb}m" \
      MakeSitesOnlyVcf \
      --TMP_DIR {params.tmp_dir} \
      -I results/hard_filter/{CALLSET_NAME}.{wildcards.scatter}.variant_filtered.vcf.gz \
      -O results/hard_filter/{CALLSET_NAME}.{wildcards.scatter}.sites_only.variant_filtered.vcf.gz
    """
