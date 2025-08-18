Automatic detection of rat ultrasonic vocalizations
================
Marcelo Araya-Salas
2025-08-18

This repository contains the example data and code to automatically
detect rat ultrasonic vocalizations (USV). The examples sound files are
found at `./data/raw/sound_files`. Automatic detection is conducted with
the R package [ohun](https://docs.ropensci.org/ohun/). Detection are
further curated by mitigating false positives with a Random Forest on
spectrographic features.

## Analysis

This script details the entire process of analysis, from sound file
formatting to summarizing results:

<https://rpubs.com/marcelo-araya-salas/detecting_rat_suvs>

The script offers code to detect USVs in three possible escenarios:

- Detect 55 kHz USVs in the presence of bedding
- Detect 55 kHz USVs with no bedding
- Detect 22 kHz USVs with no bedding

Associated random forest models are hosted at:

<https://doi.org/10.6084/m9.figshare.29931746.v1>

## Contact

Created by [Marcelo Araya-Salas](https://marce10.github.io/)
