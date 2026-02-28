rule train_variant_annotations_model:
  input:
    signal=rules.extract_variant_annotations.output.singal,
  output:
    singal=touch("results/train_variant_annotations_model.ok"),
  params: 
    tmp_dir=config["params"].get("tmp_dir"),
  container: config["environments"].get("gatk")
  log: "logs/train_variant_annotations_model.log"
  run:
    from pathlib import Path
    output_prefix = f"results/{CALLSET_NAME}.train"
    shell(
      """
      exec >> {log} 2>&1
      gatk --java-options "-Xmx{resources.mem_mb}m" \
        TrainVariantAnnotationsModel \
          --tmp-dir {params.tmp_dir} \
          --annotations-hdf5 results/{CALLSET_NAME}.extract.annot.hdf5 \
          -O {output_prefix}
      """
    )
