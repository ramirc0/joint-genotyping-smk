# joint-genotyping-smk

A [Snakemake](https://github.com/snakemake/snakemake) pipeline that jointly
genotypes reblocked gVCFs. GenomicsDBImport and GenotypeGVCFs call each interval
scatter. An ExcessHet hard filter follows. GATK's Variant Extract-Train-Score
(VETS) tools then filter the sites, and the scatters are gathered into one VCF.
The inputs come from
[wgs-smk](https://github.com/christian728504/wgs-smk.git) or the
[WARP Whole Genome Germline Single Sample pipeline](https://broadinstitute.github.io/warp/docs/Pipelines/Whole_Genome_Germline_Single_Sample/README).

> [!NOTE]
> This pipeline is based on the [WARP JointGenotyping pipeline](https://broadinstitute.github.io/warp/docs/Pipelines/JointGenotyping_Pipeline/README) by the Broad Institute, [originally licensed](https://github.com/broadinstitute/warp/blob/develop/LICENSE) under BSD. See [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES) for details.

## Layout

```
config/
  config.yaml.template   parameters + paths; copy to config.yaml (gitignored)
  sample_map.example.tsv headerless: sample ID, gVCF path
workflow/
  Snakefile              includes the rule files, onstart hook, rule all
  rules/
    common.smk           config, sample map checks, path constants, helpers
    genotype.smk         SplitIntervals, GenomicsDBImport, GenotypeGVCFs, hard filter, gather
    vets.smk             ExtractVariantAnnotations, Train, Score, final gather
    qc.smk               dbSNP reheader, CollectVariantCallingMetrics
  envs/pixi.toml         rule envs (pixi workspace): default and gatk
.tests/integration/      100 1000 Genomes samples on a 348 kb chr20 window
profiles/
  local/config.yaml      local execution
  slurm/config.yaml      SLURM (per-rule resources, retried with more memory)
pixi.toml                launcher env + test task
```

## Running

```bash
cp config/config.yaml.template config/config.yaml        # then edit
cp config/sample_map.example.tsv config/sample_map.tsv   # then edit
pixi shell                                               # launcher env
snakemake -n -p --profile profiles/local                 # dry run
snakemake --profile profiles/local                       # local
snakemake --profile profiles/slurm                       # SLURM
```

The SLURM profile holds Weng Lab cluster settings, such as partitions and the
`cascadelake` constraint. Adapt them for another cluster with the
[SLURM executor docs](https://snakemake.github.io/snakemake-plugin-catalog/plugins/executor/slurm.html).
Tune `set-resources` from the `benchmarks/<run_id>/` TSVs after a first run.

## Integration test

```bash
pixi run test
```

It runs every rule in `.tests/integration/` with the local profile, in about
two minutes. The inputs are the reblocked gVCFs of 100 unrelated 1000 Genomes
30x samples from a wgs-smk run, cut to `chr20:1-347695`. They cover all 26
populations, 50 male and 50 female. A hundred samples pass the default
`sample_num_threshold` and make GenomicsDBImport run two batches.
A dry run first checks that a threshold equal to the sample count passes.
`make_test_data.sh` records how the inputs were built. It is not part of the
test.

## Inputs

The sample map is a headerless TSV. Column one is the sample ID and column two
is its gVCF. GenomicsDBImport reads it as `--sample-name-map`. The workflow
checks it while it parses, so a dry run fails too. It fails when a gVCF is
missing, when a sample ID repeats, or when the map has fewer than
`sample_num_threshold` samples.

Download the references into `resources/` (gitignored):

```bash
curl -fsSL https://users.wenglab.org/ramirezc/mohd/resources/joint-genotyping-smk.tar.zst | tar --use-compress-program=zstd -xf -
curl -fsSL -o resources/wgs_calling_regions.hg38.handcurated.noCentromeres.noTelomeres.interval_list \
    https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0/wgs_calling_regions.hg38.handcurated.noCentromeres.noTelomeres.interval_list
```

The calling intervals are the Broad's hand-curated 20k list without centromeres
and telomeres. They cover 3.02 Gb in 19,694 intervals.

The `.fai` and `.dict` MUST sit beside the FASTA. dbSNP MUST be a plain VCF
with a GATK `.idx`.

## Configuration

| Key | Meaning |
|---|---|
| `sample_map` | Sample map path. |
| `callset_name` | Prefix of every callset file. |
| `outdir` | Results root. |
| `run_id` | Run name. Outputs go under `results/<run_id>/`. |
| `pixi_env` | Environment of `workflow/envs/pixi.toml` that the metrics rule uses. |
| `tmp_dir` | GATK and Picard scratch. Each run empties it at start, so it MUST hold nothing else. It MUST NOT sit on a `noexec` mount, as `/tmp` is on some hosts. |
| `references.fasta` | Reference genome FASTA. |
| `references.dbsnp_vcf` | dbSNP VCF for GenotypeGVCFs and the metrics. |
| `references.eval_interval_list` | Target intervals for the metrics. |
| `references.unpadded_interval_list` | Calling intervals to scatter. Sites outside them are not called. |
| `references.*_resource_vcf` | HapMap, Omni, 1000G and Mills VETS resources. |
| `sample_num_threshold` | The map needs at least this many samples, as in WARP. Default `50`. |
| `scatter_count` | Number of scatters. About `round(0.15 * number of gVCFs)`. |
| `scatter_mode` | SplitIntervals `-mode`. |
| `batch_size` | GenomicsDBImport `--batch-size`. |
| `excess_het_threshold` | Sites with a larger ExcessHet get the `ExcessHet` filter. |
| `snp_recalibration_annotation_values` | VETS annotations, passed as `-A`. |
| `snp_calibration_sensitivity_threshold` | SNPs at or above this calibration sensitivity get `LOW_SCORE`. Default `0.997`, WARP's VQSR SNP level. |
| `indel_calibration_sensitivity_threshold` | The same for indels. Default `0.99`, WARP's VQSR indel level. |

## Outputs

Everything goes under `results/<run_id>/`. Logs and benchmarks go to
`logs/<run_id>/` and `benchmarks/<run_id>/`.

| Path | Contents |
|---|---|
| `scatter_dir/` | Scattered interval lists |
| `genotype_gvcfs/` | Per-scatter joint calls. Each job builds its GenomicsDB workspace on local disk and discards it. |
| `hard_filter/` | ExcessHet-filtered and sites-only VCFs |
| `<callset>.sites_only.vcf.gz` | Gathered sites-only VCF |
| `<callset>.extract.*` | VETS annotations and labeled sites |
| `<callset>.train.{snp,indel}.*` | VETS scorers and score files |
| `score_variant_annotations/` | Per-scatter scored VCFs |
| `<callset>.final.vcf.gz` | Final joint VCF |
| `dbsnp.vcf.gz` | dbSNP bgzipped, with the reference contig lines Picard needs |
| `<callset>.variant_calling_{detail,summary}_metrics` | Picard metrics against dbSNP |

## Environment

The launcher env (`pixi.toml` at the root) has Snakemake main and its plugins
for pixi deployment and SLURM. The rule envs live in a second pixi workspace,
`workflow/envs/`. Its `pixi.lock` pins every package. `gatk` runs GATK 4.6.2.0
on OpenJDK 17, with the scikit-learn stack that VETS needs. `default` runs
Picard and bcftools. pixi MUST be on `PATH`.

The versions match the images that produced the production results:
`us.gcr.io/broad-gatk/gatk:latest` and `clarity001/wgs-smk:latest`, both pulled
on 2026-07-11. conda-forge lacks their exact OpenJDK builds, so the envs use
17.0.13 and 21.0.10.

Add a dependency with `pixi add <pkg>` in `workflow/envs/`. After a hand edit,
run `pixi lock` there (rules use `locked=True`). Any change to the manifest or
lock reruns every rule. So does moving the workdir, because the env hash includes
the workspace's absolute path.

## Conventions

The workflow follows the
[Nextstrain Snakemake style guide](https://docs.nextstrain.org/en/latest/reference/snakemake-style-guide.html)
and [Snakemake's best practices](https://snakemake.readthedocs.io/en/stable/snakefiles/best_practices.html):

- No `run:` blocks.
- Raw, triple-quoted `shell` blocks (`r"""`), one option per line.
- Every interpolation uses `:q` quoting, except inside a double-quoted string
  such as GATK's `--java-options`.
- Config reaches `shell` through `params:` (a `lambda`), never directly.
- `input:` and `output:` are literal path strings. All paths are relative.
- Rules tee logs to file and terminal (`exec &> >(tee {log:q})`).
- Shell blocks end with `sync {output:q}`. On a shared filesystem, Snakemake's
  first stat of an output from the submit host otherwise waits for the
  writing node to flush it.
- Every rule has `log:` and `benchmark:`. Each names its pixi env in `software:`.
- Every rule declares its real outputs. There are no sentinel files and no `localrules`.

## References

> Köster, J., Mölder, F., Jablonski, K. P., Letcher, B., Hall, M. B., Tomkins-Tinch, C. H., Sochat, V., Forster, J., Lee, S., Twardziok, S. O., Kanitz, A., Wilm, A., Holtgrewe, M., Rahmann, S., & Nahnsen, S. _Sustainable data analysis with Snakemake_. F1000Research, 10:33, 10, 33, **2021**. https://doi.org/10.12688/f1000research.29032.2.
> https://github.com/broadinstitute/warp/blob/develop/pipelines/wdl/dna_seq/germline/joint_genotyping/JointGenotyping.wdl
> https://github.com/broadinstitute/warp/blob/develop/tasks/wdl/JointGenotypingTasks.wdl
> https://raw.githubusercontent.com/broadinstitute/gatk/4.5.0.0/scripts/vcf_site_level_filtering_wdl/JointVcfFiltering.wdl

## Questions

Open an issue or contact the MOHD DACC.
