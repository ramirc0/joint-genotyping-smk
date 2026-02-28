rule import_gvcfs:
  input:
    signal=rules.split_interval_list.output.singal,
    sample_map=config["input"].get("sample_map"),
  output:
    signal=touch("results/import_gvcfs/{scatter}.ok"),
  params:
    batch_size=config["params"].get("batch_size"),
  container: config["environments"].get("gatk")
  log: "logs/import_gvcfs/{scatter}.log"
  run:
    unpadded_interval_list = scatter_lookup(wildcards)
    shell(
      """
      exec >> {log} 2>&1
      gatk --java-options "-Xms8000m -Xmx{resources.mem_mb}m" \
        GenomicsDBImport \
        --genomicsdb-workspace-path results/import_gvcfs/{wildcards.scatter} \
        --batch-size {params.batch_size} \
        -L {unpadded_interval_list} \
        --sample-name-map {input.sample_map} \
        --reader-threads {resources.threads} \
        --merge-input-intervals \
        --consolidate

      tar -cvf results/import_gvcfs/{wildcards.scatter}.tar results/import_gvcfs/{wildcards.scatter}
      """
    )
