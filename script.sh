#!/bin/bash
set -e # abort on error

spws="18"
#spws="6 12 18"
#spws="4 6 8 10 12 14 16 18"

for spw in $spws
do
    # 1. Accumulate visibilities to characterize the horizon RFI
    #pipeline/getdata_noremoval.sh $spw
    #pipeline/folddata.sh $spw visibilities visibilities-no-source-removal
    #pipeline/integrate.sh $spw visibilities-no-source-removal integrated

    # 2. Remove sources from the visibilities
    #pipeline/getdata.sh $spw
    pipeline/getmmodes.sh $spw
    pipeline/getalm.sh $spw mmodes alm 0.01
    pipeline/makemap.sh $spw alm map

    #pipeline/makemovie.sh $spw
    #pipeline/getmodel.sh $spw alm mmodes-model visibilities-model

    #pipeline/residualsvd.sh $spw visibilities visibilities-model
    ##pipeline/imagesvd.sh $spw 100
    #pipeline/reconstruct.sh $spw visibilities visibilities-reconstructed mmodes-reconstructed 20
    #pipeline/getalm.sh $spw mmodes-reconstructed alm-reconstructed 0.01
    #pipeline/makemap.sh $spw alm-reconstructed map-reconstructed

    #pipeline/getmodel.sh $spw alm-reconstructed mmodes-model-2 visibilities-model-2
    #pipeline/residualsvd.sh $spw visibilities visibilities-model-2
    #pipeline/reconstruct.sh $spw visibilities visibilities-reconstructed-2 mmodes-reconstructed-2 20
    #pipeline/getalm.sh $spw mmodes-reconstructed-2 alm-reconstructed-2 0.01
    #pipeline/makemap.sh $spw alm-reconstructed-2 map-reconstructed-2
done

