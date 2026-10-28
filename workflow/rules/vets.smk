# Variant Extract-Train-Score filtering and the final gather.


rule extract_variant_annotations:
    input:
        vcf=f"{OUTDIR}/{CALLSET}.sites_only.vcf.gz",
        resource_vcfs=list(VETS_RESOURCES.values()),
    output:
        annot=f"{OUTDIR}/{CALLSET}.extract.annot.hdf5",
        vcf=f"{OUTDIR}/{CALLSET}.extract.vcf.gz",
        tbi=f"{OUTDIR}/{CALLSET}.extract.vcf.gz.tbi",
    params:
        tmp_dir=lambda w: config["tmp_dir"],
        prefix=f"{OUTDIR}/{CALLSET}.extract",
        annotations=lambda w: repeat_flag("-A", config["snp_recalibration_annotation_values"]),
        resource_args=VETS_RESOURCE_ARGS,
    log:
        f"{LOGDIR}/extract_variant_annotations.txt",
    benchmark:
        f"{BENCHDIR}/extract_variant_annotations.tsv",
    software:
        GATK_ENV
    shell:
        r"""
        exec &> >(tee {log:q})

        gatk --java-options "-Xmx$(({resources.mem_mb} - 2000))m" \
            ExtractVariantAnnotations \
            --tmp-dir {params.tmp_dir:q} \
            -V {input.vcf:q} \
            -O {params.prefix:q} \
            {params.annotations:q} \
            {params.resource_args:q}

        sync {output:q}
        """


# The heap stays small because the scikit-learn subprocess needs the rest of mem_mb.
rule train_variant_annotations_model:
    input:
        f"{OUTDIR}/{CALLSET}.extract.annot.hdf5",
    output:
        VETS_MODEL,
    params:
        tmp_dir=lambda w: config["tmp_dir"],
        prefix=f"{OUTDIR}/{CALLSET}.train",
    log:
        f"{LOGDIR}/train_variant_annotations_model.txt",
    benchmark:
        f"{BENCHDIR}/train_variant_annotations_model.tsv",
    software:
        GATK_ENV
    shell:
        r"""
        exec &> >(tee {log:q})

        gatk --java-options "-Xmx6000m" \
            TrainVariantAnnotationsModel \
            --tmp-dir {params.tmp_dir:q} \
            --annotations-hdf5 {input:q} \
            -O {params.prefix:q}

        sync {output:q}
        """


rule score_variant_annotations:
    input:
        vcf=f"{OUTDIR}/hard_filter/{CALLSET}.{{scatter}}.variant_filtered.vcf.gz",
        extracted_vcf=f"{OUTDIR}/{CALLSET}.extract.vcf.gz",
        model=VETS_MODEL,
        resource_vcfs=list(VETS_RESOURCES.values()),
    output:
        vcf=f"{OUTDIR}/score_variant_annotations/{CALLSET}.{{scatter}}.score.vcf.gz",
        tbi=f"{OUTDIR}/score_variant_annotations/{CALLSET}.{{scatter}}.score.vcf.gz.tbi",
    params:
        tmp_dir=lambda w: config["tmp_dir"],
        prefix=f"{OUTDIR}/score_variant_annotations/{CALLSET}.{{scatter}}.score",
        model_prefix=f"{OUTDIR}/{CALLSET}.train",
        annotations=lambda w: repeat_flag("-A", config["snp_recalibration_annotation_values"]),
        resource_args=VETS_RESOURCE_ARGS,
    log:
        f"{LOGDIR}/score_variant_annotations/{{scatter}}.txt",
    benchmark:
        f"{BENCHDIR}/score_variant_annotations/{{scatter}}.tsv",
    software:
        GATK_ENV
    shell:
        r"""
        exec &> >(tee {log:q})

        gatk --java-options "-Xmx6000m" \
            ScoreVariantAnnotations \
            --tmp-dir {params.tmp_dir:q} \
            -V {input.vcf:q} \
            -O {params.prefix:q} \
            {params.annotations:q} \
            {params.resource_args:q} \
            --resource:extracted,extracted=true {input.extracted_vcf:q} \
            --model-prefix {params.model_prefix:q}

        sync {output:q}
        """


rule gather_final_vcf:
    input:
        expand(
            f"{OUTDIR}/score_variant_annotations/{CALLSET}.{{scatter}}.score.vcf.gz",
            scatter=SCATTERS,
        ),
    output:
        vcf=f"{OUTDIR}/{CALLSET}.final.vcf.gz",
        tbi=f"{OUTDIR}/{CALLSET}.final.vcf.gz.tbi",
    params:
        tmp_dir=lambda w: config["tmp_dir"],
        vcfs=lambda w, input: repeat_flag("--input", input),
    log:
        f"{LOGDIR}/gather_final_vcf.txt",
    benchmark:
        f"{BENCHDIR}/gather_final_vcf.tsv",
    software:
        GATK_ENV
    shell:
        r"""
        exec &> >(tee {log:q})

        gatk --java-options "-Xms6000m -Xmx$(({resources.mem_mb} - 6000))m" \
            GatherVcfsCloud \
            --tmp-dir {params.tmp_dir:q} \
            --ignore-safety-checks \
            --gather-type BLOCK \
            {params.vcfs:q} \
            --output {output.vcf:q}

        tabix {output.vcf:q}

        sync {output:q}
        """
