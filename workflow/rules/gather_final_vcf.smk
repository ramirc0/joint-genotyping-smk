rule gather_final_vcf:
  input:
    **gather_score_variant_annotations_signals(),
  output:
    signal=touch("results/gather_final_vcf.ok"),
  params:
    tmp_dir=config["params"].get("tmp_dir"),
  container: config["environments"].get("gatk")
  log: "logs/gather_final_vcf.log"
  run:
    score_variant_annotations_vcfs = [f"results/score_variant_annotations/{CALLSET_NAME}.{scatter}.score.vcf.gz" for scatter in range(config["params"].get("scatter_count"))]
    score_variant_annotations_vcfs_str = " --input ".join(score_variant_annotations_vcfs)
    shell(
      """
      exec >> {log} 2>&1
      gatk --java-options "-Xms6000m -Xmx{resources.mem_mb}m" \
        GatherVcfsCloud \
        --tmp-dir {params.tmp_dir} \
        --ignore-safety-checks \
        --gather-type BLOCK \
        --input {score_variant_annotations_vcfs_str} \
        --output results/{CALLSET_NAME}.final.vcf.gz

      tabix results/{CALLSET_NAME}.final.vcf.gz
      """
    )
