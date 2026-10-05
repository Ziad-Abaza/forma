-- Forma Database Migration 011: Complete Full Anthropometric & Circumference Catalog (Blueprint §7.2, §7.5)

INSERT INTO measurement_types (code, category, dimension, canonical_unit, allowed_units, min_plausible, max_plausible, laterality, is_user_enterable, is_derived)
VALUES
    ('shoulder_circumference', 'circumference', 'length', 'cm', ARRAY['cm', 'in'], 50.0000, 250.0000, 'none', true, false),
    ('forearm_circumference', 'circumference', 'length', 'cm', ARRAY['cm', 'in'], 10.0000, 70.0000, 'bilateral', true, false),
    ('calf_circumference', 'circumference', 'length', 'cm', ARRAY['cm', 'in'], 15.0000, 90.0000, 'bilateral', true, false)
ON CONFLICT (code) DO UPDATE SET
    category = EXCLUDED.category,
    dimension = EXCLUDED.dimension,
    canonical_unit = EXCLUDED.canonical_unit,
    allowed_units = EXCLUDED.allowed_units,
    min_plausible = EXCLUDED.min_plausible,
    max_plausible = EXCLUDED.max_plausible,
    laterality = EXCLUDED.laterality,
    is_user_enterable = EXCLUDED.is_user_enterable,
    is_derived = EXCLUDED.is_derived;
