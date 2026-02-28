rule score_variant_annotations:
  input:
    signal=rules.train_variant_annotations_model.output.singal,
    hapmap_resource_vcf=config["resources"].get("hapmap_resource_vcf"),
    omni_resource_vcf=config["resources"].get("omni_resource_vcf"),
    one_thousand_genomes_resource_vcf=config["resources"].get("one_thousand_genomes_resource_vcf"),
    mills_resource_vcf=config["resources"].get("mills_resource_vcf"),
  output:
    singal=touch("results/score_variant_annotations/{scatter}.ok"),
  params:
    tmp_dir=config["params"].get("tmp_dir"),
    annotations=" -A ".join(config["params"].get("snp_recalibration_annotation_values")),
  container: config["environments"].get("gatk")
  log: "logs/score_variant_annotations/{scatter}.log"
  run:
    resource_args = (
      f" --resource:hapmap,training=true,calibration=true {input.hapmap_resource_vcf}"
      f" --resource:omni,training=true,calibration=true {input.omni_resource_vcf}"
      f" --resource:1000G,training=true {input.one_thousand_genomes_resource_vcf}" 
      f" --resource:mills,training=true,calibration=true {input.mills_resource_vcf}"
    )
    model_prefix = f"results/{CALLSET_NAME}.train"
    output_prefix = f"results/score_variant_annotations/{CALLSET_NAME}.{wildcards.scatter}.score"
    shell(
      """
      exec >> {log} 2>&1
      gatk --java-options "-Xmx{resources.mem_mb}m" \
        ScoreVariantAnnotations \
          --tmp-dir {params.tmp_dir} \
          -V results/hard_filter/{CALLSET_NAME}.{wildcards.scatter}.variant_filtered.vcf.gz \
          -O {output_prefix} \
          -A {params.annotations} \
          {resource_args} \
          --resource:extracted,extracted=true results/{CALLSET_NAME}.extract.vcf.gz \
          --model-prefix {model_prefix}
      """
    )
