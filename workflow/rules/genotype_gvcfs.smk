rule genotype_gvcfs:
  input: 
    signal=rules.import_gvcfs.output.signal,
    reference_fasta=config["resources"].get("reference_fasta"),
    dbsnp_vcf=config["resources"].get("dbsnp_vcf"),
  output:
    singal=touch("results/genotype_gvcfs/{scatter}.ok"),
  params:
    tmp_dir=config["params"].get("tmp_dir"),
  container: config["environments"].get("gatk")
  log: "logs/genotype_gvcfs/{scatter}.log"
  run:
    unpadded_interval_list = scatter_lookup(wildcards)
    shell(
      """
      exec >> {log} 2>&1
      gatk --java-options "-Xms8000m -Xmx{resources.mem_mb}m" \
        GenotypeGVCFs \
          --tmp-dir {params.tmp_dir} \
          -R {input.reference_fasta} \
          -O results/genotype_gvcfs/{CALLSET_NAME}.{wildcards.scatter}.vcf.gz \
          -D {input.dbsnp_vcf} \
          -G StandardAnnotation -G AS_StandardAnnotation \
          --only-output-calls-starting-in-intervals \
          -V gendb://results/import_gvcfs/{wildcards.scatter} \
          -L {unpadded_interval_list} \
          --merge-input-intervals
      """
    )
