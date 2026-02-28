rule extract_variant_annotations:
  input:
    signal=rules.gather_sites_only_vcfs.output.singal,
    hapmap_resource_vcf=config["resources"].get("hapmap_resource_vcf"),
    omni_resource_vcf=config["resources"].get("omni_resource_vcf"),
    one_thousand_genomes_resource_vcf=config["resources"].get("one_thousand_genomes_resource_vcf"),
    mills_resource_vcf=config["resources"].get("mills_resource_vcf"),
  output:
    singal=touch("results/extract_variant_annotations.ok"),
  params:
    tmp_dir=config["params"].get("tmp_dir"),
    annotations=" -A ".join(config["params"].get("snp_recalibration_annotation_values")),
  container: config["environments"].get("gatk")
  log: "logs/extract_variant_annotations.log"
  run:
    from pathlib import Path
    resource_args = (
      f" --resource:hapmap,training=true,calibration=true {input.hapmap_resource_vcf}"
      f" --resource:omni,training=true,calibration=true {input.omni_resource_vcf}"
      f" --resource:1000G,training=true {input.one_thousand_genomes_resource_vcf}" 
      f" --resource:mills,training=true,calibration=true {input.mills_resource_vcf}"
    )
    output_prefix = f"results/{CALLSET_NAME}.extract"
    shell(
      """
      exec >> {log} 2>&1
      gatk --java-options "-Xmx{resources.mem_mb}m" \
        ExtractVariantAnnotations \
        --tmp-dir {params.tmp_dir} \
        -V results/{CALLSET_NAME}.sites_only.vcf.gz \
        -O {output_prefix} \
        -A {params.annotations} \
        {resource_args}
      """
    )
