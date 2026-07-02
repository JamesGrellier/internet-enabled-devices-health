# Disentangling pathways between Internet-enabled device use and health: a systematic mapping review of reviews - Systems map



## Overview

This repository contains interactive systems maps of relationships identified in a systematic evidence map of reviews examining the health impacts of internet-enabled device use (Figure 1).

The visualisation was created using R and HTML to provide a fully reproducible, platform-independent, and archivable version of the map.

The interactive systems maps allow users to explore relationships between exposures, outcomes and moderators identified in the review, together with the supporting references from the evidence base.

<p align="center">
    <img src="Images/Systems map screenshot.png" width="900">
</p>
Figure 1

## Contents

### Interactive maps

The repository contains a series of interactive HTML maps, including:

* Complete map of all identified relationships
* Theme-specific maps
* Positive-impact relationships only
* Negative-impact relationships only

Each map allows users to:

* Explore relationships between concepts
* View supporting references for individual connections
* Navigate between thematic subsets of the evidence base

The main entry point is:

`index.html`

### Source data

The repository includes the source data used to generate the maps:

* `20260616 GOLIATmap.xlsx`

Additional processed data files include:

* `nodes_with_coords_sized.csv`
* `edges_collapsed.csv`

### Code

The repository includes an R script (`GOLIAT Create systems map.R`) used to:

* Process source data
* Generate node coordinates
* Create interactive visNetwork visualisations (systems maps)
* Export standalone HTML maps

## Reproducibility

All visualisations were generated using open-source software, principally:

* R
* tidyverse
* visNetwork
* htmltools

## Version

Version 0.9

## Citation

If you use these materials, please cite the associated publication:

Grellier, J., Martin, L., White, M.P., de Vocht, F., Röösli, M., Guxens, M. Disentangling pathways between internet-enabled device use and human health: A systematic evidence map of reviews. (Under review).

Archived version of this repository:

DOI: [INSERT ZENODO DOI HERE]

## Licence

This repository contains both software and research outputs, which are licensed separately.

| Content | Licence |
|---------|----------|
| R source code (`*.R`) | GNU General Public License v3.0 (GPL-3.0) |
| Interactive systems maps (`*.html`) | Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0) |
| Curated evidence datasets (`*.csv`, `*.xlsx`) | Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0) |
| Documentation (`README.md`) | Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0) |
| Figures and screenshots (`images/*`) | Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0) |

See the LICENSE file for full licensing information.

## Author

Dr James Grellier<br/>
European Centre for Environment and Human Health<br/>
University of Exeter<br/>
United Kingdom<br/>

## Contact

For questions regarding the map, source data, or associated publication, please contact the repository author.
