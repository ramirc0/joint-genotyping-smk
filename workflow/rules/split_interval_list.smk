rule split_interval_list:
  input:
    signal=rules.check_sample_map.output.singal,
    unpadded_interval_list=config["resources"].get("unpadded_interval_list"),
    reference_fasta=config["resources"].get("reference_fasta"),
  output:
    singal=touch("results/split_interval_list.ok"),
  params:
    scatter_count=config["params"].get("scatter_count"),
    scatter_mode=config["params"].get("scatter_mode"),
  log: "logs/split_interval_list.log"
  container: config["environments"].get("gatk")
  shell:
    """
    exec >> {log} 2>&1
    gatk --java-options "-Xms3000m -Xmx{resources.mem_mb}m" SplitIntervals \
      -L {input.unpadded_interval_list} \
      -O results/scatter_dir \
      -scatter {params.scatter_count} \
      -R {input.reference_fasta} \
      -mode {params.scatter_mode} \
      --interval-merging-rule OVERLAPPING_ONLY 
    """
