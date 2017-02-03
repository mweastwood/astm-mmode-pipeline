function getmodeldata()
    ms = Table("workspace/calibrations/day1.ms")
    meta = read_meta_from_ms(ms)
    unlock(ms)

    mmodes = MModes("workspace/model-mmodes-test")
    visibilities = GriddedVisibilities("workspace/model-visibilities", meta, mmodes, 6628)
    nothing
end

