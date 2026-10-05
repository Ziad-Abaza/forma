-- Forma Database Migration 002: Seed Core Measurement Types Catalog

INSERT INTO measurement_types (code, category, dimension, canonical_unit, allowed_units, min_plausible, max_plausible, laterality, is_user_enterable, is_derived)
VALUES
    ('weight', 'anthropometric', 'mass', 'kg', ARRAY['kg', 'lb', 'st'], 20.0000, 350.0000, 'none', true, false),
    ('body_fat_percentage', 'composition', 'ratio', 'percent', ARRAY['percent'], 3.0000, 70.0000, 'none', true, false),
    ('muscle_mass', 'composition', 'mass', 'kg', ARRAY['kg', 'lb'], 10.0000, 200.0000, 'none', true, false),
    ('body_water_percentage', 'composition', 'ratio', 'percent', ARRAY['percent'], 20.0000, 80.0000, 'none', true, false),
    ('visceral_fat', 'composition', 'dimensionless', 'score', ARRAY['score'], 1.0000, 59.0000, 'none', true, false),
    ('bone_mass', 'composition', 'mass', 'kg', ARRAY['kg', 'lb'], 0.5000, 15.0000, 'none', true, false),
    ('waist_circumference', 'circumference', 'length', 'cm', ARRAY['cm', 'in'], 40.0000, 250.0000, 'none', true, false),
    ('hip_circumference', 'circumference', 'length', 'cm', ARRAY['cm', 'in'], 50.0000, 250.0000, 'none', true, false),
    ('chest_circumference', 'circumference', 'length', 'cm', ARRAY['cm', 'in'], 50.0000, 250.0000, 'none', true, false),
    ('neck_circumference', 'circumference', 'length', 'cm', ARRAY['cm', 'in'], 20.0000, 80.0000, 'none', true, false),
    ('thigh_circumference', 'circumference', 'length', 'cm', ARRAY['cm', 'in'], 25.0000, 120.0000, 'bilateral', true, false),
    ('bicep_circumference', 'circumference', 'length', 'cm', ARRAY['cm', 'in'], 15.0000, 80.0000, 'bilateral', true, false),
    ('height', 'anthropometric', 'length', 'cm', ARRAY['cm', 'in', 'ft'], 80.0000, 260.0000, 'none', true, false),
    ('bmi', 'composition', 'ratio', 'kg_per_m2', ARRAY['kg_per_m2'], 10.0000, 80.0000, 'none', false, true)
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
