# Joint Genotyping Snakemake Pipeline

## Overview

Here we present a [snakemake](https://github.com/snakemake/snakemake.git) pipeline for variant calling and filtering jointly across multiple samples.

> [!NOTE]
> This pipeline is based on [WARP JointGenotyping pipeline](https://broadinstitute.github.io/warp/docs/Pipelines/JointGenotyping_Pipeline/README) by the Broad Institute, [originally licensed](https://github.com/broadinstitute/warp/blob/develop/LICENSE) under BSD. See [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES) for details.

## Example Usage

### Prerequisites

To run this pipeline, you will need to have previously ran the [WARP Whole Genome Germline Single Sample pipeline](https://broadinstitute.github.io/warp/docs/Pipelines/Whole_Genome_Germline_Single_Sample/README) or our snakemake equivalent, [wgs-smk]().

### Dependcies

This pipeline requires the following dependencies to be ran:

- [`conda` (preferably `mamba`)](https://github.com/conda-forge/miniforge)
- [`singularity`](https://docs.sylabs.io/guides/3.0/user-guide/installation.html)
- (Optional) [`slurm`](https://slurm.schedmd.com/quickstart.html)

To start, first setup the runtime environment:

```bash
mamba env create --name=joint-genotyping-smk --file=environments/joint-genotyping-smk.yaml
mamba activate joint-genotyping-smk
```

Then, download the required resources:

```bash
curl -fsSL https://users.wenglab.org/ramirezc/mohd/resources/joint-genotyping-smk-resources.tar.zst | tar --use-compress-program=zstd -xf -
```

### Example Configfile

For a complete example, see [config/config.yml](config/config.yml). Form this file you'll want to pay attention to the following sections:

```yaml
input:
  slack_webhook_url: MY_SLACK_WEBHOOK_URL
  sample_map: "MOHD.sample_map.tsv"
  callset_name: "MOHD"
```

- `input.slack_webhook_url`: (Optional) This is the webhook URL for your [Slack app](https://docs.slack.dev/app-management/quickstart-app-settings/). This is for a convenience feature so that messages will be sent about that status of your running snakemake pipeline.
- `input.sample_map`: This is the path to your sample map file. It is a tab-delimited file with no header. The first column contains sample IDs which *must be unique* and the second column contains the path to the corresponding gVCF. To see a complete example with the Phase 0 MOHD paticipants, see [MOHD.sample_map.tsv](MOHD.sample_map.tsv).
- `input.callset_name`: This is the name of your callset. In our case, it is `MOHD`.

```yaml
params:
  sample_num_threshold: 50
  scatter_count: 10
  scatter_mode: "BALANCING_WITHOUT_INTERVAL_SUBDIVISION_WITH_OVERFLOW"
  tmp_dir: ".tmp"
  batch_size: 50
  excess_het_threshold: 54.69
  snps_variant_recalibration_threshold: 500000 
  snp_recalibration_annotation_values: ["QD", "MQRankSum", "ReadPosRankSum", "FS", "MQ", "SOR", "DP"] 

```

These key-value pairs are mainly parameters for the varias command-line tools used in the pipeline (i.e. `gatk`). However you'll mainly want to pay attention to the following:

- `params.sample_num_threshold`: This is the minimum number of samples that must be present in a scatter. By default, this is set to 50. We do not recommend running this pipeline if your callset has fewer than 50 samples.
- `params.scatter_count`: The gather-scatter-gather pattern used to parallelize operations relies on an interval list (of genomic coordinates) file and a scatter count. When running the pipeline, the interval list is split into parts depending on the scatter count. These interval lists dicate the degree of parallelism in subsequent operations. It is recommended to set the scatter count according to the following calculation: `round(0.15 * num_gvcfs)`.
- `params.tmp_dir`: This is the temporary directory for intermediate files. In some compute enivornments, `/tmp` is mounted with `noexec`. In this case, you'll need to set this to `.tmp`. Otherwise, certain command-line tools which write to the temporary directory will raise errors.

### Defining resources

All resource definitions for rules are located in [profile/slurm/config.yaml](profile/slurm/config.yaml). 

```yaml
  import_gvcfs:
    runtime: 7200m
    constraint: cascadelake
    slurm_extra: "--cpu-freq=High-High:Performance"
    slurm_partition: 5days
    threads: 6
    cpus_per_task: 6
    mem: 25000MB
```

In this instance, we are requesting a job on a SLURM cluster with a runtime of 7200 minutes, a specific constraint (i.e. cascadelake), a specific partition (i.e. 5days), 6 threads, 6 CPUs per task, and 25000MB of memory.
These resource definitions are specific to the Weng Lab's SLURM cluster. If you are running the pipeline on your own cluster, you'll need to adjust these values accordingly. We recommend consulting the [snakemake-executor-plugin-surm documentation](https://snakemake.github.io/snakemake-plugin-catalog/plugins/executor/slurm.html) for further information.

### Running the Pipeline

With the hard part out of the way, you can now run the pipeline:

```bash
snakemake --workflow-profile profile/slurm 
```

> [!NOTE]
> It is recommended that you run the pipeline in dry run mode first (add the `-n` flag). Also note that `snakemake` must be ran in the root of this repository.

This will run the pipeline and produce all outputs to a folder directory `results`.

### What if I cannot run on a SLURM cluster?

If you cannot run the pipeline on a SLURM cluster, you can run it locally. However, this is not a supported use case. First got to the [workflow/Snakefile](workflow/Snakefile) and comment out the following lines:

```python
  # # Testing
  # import_gvcfs,
  # genotype_gvcfs,
  # hard_filter,
  # gather_sites_only_vcfs,
  # extract_variant_annotations,
  # train_variant_annotations_model,
  # score_variant_annotations,
  # gather_final_vcf,
  # collect_variant_calling_metrics,
```

These are rule names. When uncommented, under the `localrules` directive, they will instead execute on the local machine.

## References

> Köster, J., Mölder, F., Jablonski, K. P., Letcher, B., Hall, M. B., Tomkins-Tinch, C. H., Sochat, V., Forster, J., Lee, S., Twardziok, S. O., Kanitz, A., Wilm, A., Holtgrewe, M., Rahmann, S., & Nahnsen, S. _Sustainable data analysis with Snakemake_. F1000Research, 10:33, 10, 33, **2021**. https://doi.org/10.12688/f1000research.29032.2.
> https://github.com/broadinstitute/warp/blob/develop/pipelines/wdl/dna_seq/germline/joint_genotyping/JointGenotyping.wdl
> https://github.com/broadinstitute/warp/blob/develop/tasks/wdl/JointGenotypingTasks.wdl
> https://raw.githubusercontent.com/broadinstitute/gatk/4.5.0.0/scripts/vcf_site_level_filtering_wdl/JointVcfFiltering.wdl

## Questions

If you have any questions or would like to provide constructive feedback, please open an issue or reach out to the MOHD DACC.
