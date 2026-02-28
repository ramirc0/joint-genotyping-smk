rule gather_sites_only_vcfs:
  input:
    **gather_sites_only_vcfs_signals(),
  output:
    singal=touch("results/gather_sites_only_vcfs.ok"),
  params:
    tmp_dir=config["params"].get("tmp_dir"),
  container: config["environments"].get("gatk")
  log: "logs/gather_sites_only_vcfs.log"
  run:
    sites_only_vcfs = [f"results/hard_filter/{CALLSET_NAME}.{scatter}.sites_only.variant_filtered.vcf.gz" for scatter in range(config["params"].get("scatter_count"))]
    sites_only_vcfs_str = " --input ".join(sites_only_vcfs)
    shell(
      """
      exec >> {log} 2>&1
      gatk --java-options "-Xms6000m -Xmx{resources.mem_mb}m" \
        GatherVcfsCloud \
        --tmp-dir {params.tmp_dir} \
        --ignore-safety-checks \
        --gather-type BLOCK \
        --input {sites_only_vcfs_str} \
        --output results/{CALLSET_NAME}.sites_only.vcf.gz

      tabix results/{CALLSET_NAME}.sites_only.vcf.gz
      """
    )
