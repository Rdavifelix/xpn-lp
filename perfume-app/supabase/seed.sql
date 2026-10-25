-- Seed data: reference vocabulary (accords, occasions, notes) plus 20 real,
-- well-known fragrances with their brand, pyramid notes, dominant accords,
-- season suitability and occasion scores. Note/accord characterizations
-- are simplified from each fragrance's well-documented public composition
-- (as commonly described by fragrance retailers/community sites) — good
-- enough to make Discovery, the fragrance detail pyramid/accord chart, and
-- the recommendation scoring function all exercise realistic data.
--
-- Junction tables reference rows by name/slug via subqueries rather than
-- hardcoded UUIDs, so a typo fails loudly (0 rows / FK violation) instead
-- of silently miswiring a relationship.
--
-- Run after all migrations, e.g.:
--   psql "$DATABASE_URL" -f supabase/seed.sql
-- or via the Supabase CLI: supabase db reset (which applies migrations then seed.sql)

begin;

-- 1. Accords ---------------------------------------------------------------
-- Broader than notes.note_family (which classifies raw ingredients) — this
-- is the descriptive vocabulary used for a *fragrance's* overall character,
-- matching how sites like Fragrantica tag dominant accords.
insert into public.accords (slug, label, hex_color) values
  ('citrus',       'Citrus',       '#E8A33D'),
  ('floral',       'Floral',       '#D998B5'),
  ('woody',        'Woody',        '#8A6240'),
  ('oriental',     'Oriental',     '#9A5B3C'),
  ('fresh',        'Fresh',        '#6FB8A8'),
  ('gourmand',     'Gourmand',     '#C97B4A'),
  ('spicy',        'Spicy',        '#B5482F'),
  ('green',        'Green',        '#7A9B5C'),
  ('aquatic',      'Aquatic',      '#4E8FB0'),
  ('musk',         'Musk',         '#B8A48C'),
  ('leather',      'Leather',      '#6B4A3A'),
  ('resin',        'Resin',        '#8C5A2B'),
  ('powdery',      'Powdery',      '#C9B8D9'),
  ('amber',        'Amber',        '#B87333'),
  ('fruity',       'Fruity',       '#E0708A'),
  ('aromatic',     'Aromatic',     '#5F8B6E'),
  ('chypre',       'Chypre',       '#6E7F5C'),
  ('earthy',       'Earthy',       '#6B5B3E'),
  ('vanilla',      'Vanilla',      '#E4C58B'),
  ('smoky',        'Smoky',        '#5A4A42'),
  ('tobacco',      'Tobacco',      '#7A5230'),
  ('boozy',        'Boozy',        '#A85C32'),
  ('white_floral', 'White Floral', '#EEC9DC'),
  ('sweet',        'Sweet',        '#E39B6B');

-- 2. Occasions ---------------------------------------------------------------
insert into public.occasions (slug, label, icon) values
  ('daily',      'Everyday',       'sunny-outline'),
  ('office',     'Office',         'briefcase-outline'),
  ('date_night', 'Date Night',     'heart-outline'),
  ('night_out',  'Night Out',      'moon-outline'),
  ('formal',     'Formal Event',   'shirt-outline'),
  ('wedding',    'Wedding',        'flower-outline'),
  ('gym',        'Gym / Sport',    'barbell-outline'),
  ('beach',      'Beach',          'water-outline'),
  ('travel',     'Travel',         'airplane-outline'),
  ('festive',    'Festive',        'sparkles-outline'),
  ('cozy_home',  'Cozy at Home',   'home-outline');

-- 3. Notes / ingredients -----------------------------------------------------
insert into public.notes (name, note_family, description) values
  ('Bergamot', 'citrus', 'Bright, slightly bitter Italian citrus — the classic top-note opener.'),
  ('Lemon', 'citrus', 'Sharp, zesty citrus peel.'),
  ('Sicilian Lemon', 'citrus', 'Sun-ripened lemon prized for its sweetness and depth.'),
  ('Mandarin', 'citrus', 'Sweet, juicy citrus, softer than orange.'),
  ('Green Mandarin', 'citrus', 'Unripe mandarin — tart and green.'),
  ('Blood Mandarin', 'citrus', 'Deep red mandarin variety with a jammy sweetness.'),
  ('Grapefruit', 'citrus', 'Tart, slightly bitter citrus with a sparkling quality.'),
  ('Orange', 'citrus', 'Round, sweet citrus.'),
  ('Bitter Orange', 'citrus', 'Sharper, less sweet than orange, used in colognes.'),
  ('Neroli', 'citrus', 'Distilled bitter-orange blossom — citrus-green and honeyed.'),
  ('Verbena', 'citrus', 'Lemony, herbaceous citrus note.'),
  ('Pink Pepper', 'spicy', 'Fruity, rosy pepper berry — softer than black pepper.'),
  ('Pepper', 'spicy', 'Warm, dry spice with a sharp bite.'),
  ('Cardamom', 'spicy', 'Warm, slightly camphorous spice.'),
  ('Cinnamon', 'spicy', 'Warm, woody-sweet spice.'),
  ('Nutmeg', 'spicy', 'Warm, slightly sweet baking spice.'),
  ('Ginger', 'spicy', 'Sharp, zesty root spice.'),
  ('Mint', 'green', 'Cool, sharp herbaceous note.'),
  ('Spearmint', 'green', 'Softer, sweeter mint.'),
  ('Green Apple', 'green', 'Crisp, tart orchard fruit.'),
  ('Juniper', 'green', 'Piney, slightly peppery berry.'),
  ('Rosemary', 'green', 'Herbaceous, camphorous green note.'),
  ('Violet Leaf', 'green', 'Cold, green, slightly metallic note.'),
  ('Geranium', 'green', 'Rosy-green leaf note.'),
  ('Clary Sage', 'green', 'Herbaceous, faintly musky sage.'),
  ('Bamboo', 'green', 'Airy, watery-green accord.'),
  ('Pelargonium', 'green', 'Rose-scented geranium relative.'),
  ('Myrtle', 'green', 'Fresh, slightly medicinal Mediterranean herb.'),
  ('Lavender', 'fresh', 'Clean, herbaceous floral — the backbone of fougère scents.'),
  ('Aldehydes', 'fresh', 'Sparkling, waxy synthetic "clean linen" effect.'),
  ('Pear', 'fresh', 'Juicy, delicate orchard fruit.'),
  ('Black Currant', 'fresh', 'Tart, slightly winey berry — a Creed Aventus signature.'),
  ('Pineapple', 'fresh', 'Sweet, tropical juicy fruit.'),
  ('Wild Strawberry', 'fresh', 'Sweet, slightly green berry.'),
  ('Litchi', 'fresh', 'Delicate, sweet-tart tropical fruit.'),
  ('Rose', 'floral', 'The classic floral — velvety, honeyed, slightly spicy.'),
  ('Bulgarian Rose', 'floral', 'Deep, rich rose absolute.'),
  ('Damask Rose', 'floral', 'Classic old-world rose, warm and honeyed.'),
  ('Jasmine', 'floral', 'Heady, indolic white floral.'),
  ('Moroccan Jasmine', 'floral', 'Rich, slightly fruity jasmine absolute.'),
  ('Ylang-Ylang', 'floral', 'Creamy, banana-like tropical floral.'),
  ('Iris', 'floral', 'Cool, powdery, earthy floral from the orris root.'),
  ('Lily of the Valley', 'floral', 'Delicate, dewy green-white floral.'),
  ('Mimosa', 'floral', 'Powdery, honeyed yellow-flower note.'),
  ('Orange Blossom', 'floral', 'Sweet, honeyed white floral.'),
  ('Hyacinth', 'floral', 'Green, slightly spicy spring floral.'),
  ('Gardenia', 'floral', 'Creamy, heady white floral.'),
  ('Orchid', 'floral', 'Exotic, slightly waxy floral.'),
  ('White Rose', 'floral', 'Fresh, dewy, less heavy than red rose.'),
  ('Lotus', 'floral', 'Delicate, slightly aquatic floral.'),
  ('Violet', 'floral', 'Soft, powdery, faintly sweet floral.'),
  ('Bluebell', 'floral', 'Fresh, green spring floral.'),
  ('Calone (Sea Notes)', 'aquatic', 'Melon-like synthetic evoking sea spray.'),
  ('Sandalwood', 'woody', 'Creamy, soft, milky wood.'),
  ('Vetiver', 'woody', 'Smoky, earthy root with a dry finish.'),
  ('Cedar', 'woody', 'Dry, pencil-shaving wood note.'),
  ('Virginia Cedar', 'woody', 'Warmer, slightly sweet cedar variety.'),
  ('White Woods', 'woody', 'Clean, modern synthetic woody accord.'),
  ('Patchouli', 'woody', 'Earthy, dark, slightly sweet wood note.'),
  ('Oakmoss', 'woody', 'Damp, forest-floor note central to chypre scents.'),
  ('Birch', 'woody', 'Smoky, slightly tarry wood note.'),
  ('Pine Needles', 'woody', 'Crisp, resinous evergreen note.'),
  ('Flint', 'woody', 'Mineral, "struck stone" accord.'),
  ('Musk', 'musk', 'Soft, skin-like base note.'),
  ('White Musk', 'musk', 'Clean, laundry-fresh musk.'),
  ('Ambergris', 'musk', 'Salty, animalic marine-amber note.'),
  ('Civet', 'musk', 'Animalic note used sparingly for warmth and depth.'),
  ('Leather', 'leather', 'Smoky, slightly bitter tanned-hide note.'),
  ('Tobacco Leaf', 'leather', 'Sweet, dried-leaf note often paired with leather.'),
  ('Labdanum', 'resin', 'Amber-like, leathery-sweet resin.'),
  ('Incense', 'resin', 'Smoky, sacred resin note.'),
  ('Opoponax', 'resin', 'Sweet, balsamic resin, softer than myrrh.'),
  ('Benzoin', 'resin', 'Warm, vanilla-like resin.'),
  ('Styrax', 'resin', 'Smoky, leathery balsamic resin.'),
  ('Elemi', 'resin', 'Peppery-fresh resin, lighter than frankincense.'),
  ('Vanilla', 'gourmand', 'Warm, sweet, comforting base note.'),
  ('Tonka Bean', 'gourmand', 'Warm, almond-hay sweetness.'),
  ('Praline', 'gourmand', 'Toasted-sugar, nutty sweetness.'),
  ('Coffee', 'gourmand', 'Roasted, bitter-sweet gourmand note.'),
  ('Bitter Almond', 'gourmand', 'Marzipan-like sweet note.'),
  ('Licorice', 'gourmand', 'Anise-like sweet, slightly medicinal note.'),
  ('Dark Chocolate', 'gourmand', 'Bitter-sweet, rich gourmand note.'),
  ('Black Truffle', 'gourmand', 'Earthy, musky gourmand rarity.'),
  ('Rum', 'gourmand', 'Sweet, boozy molasses note.'),
  ('Amber', 'oriental', 'Warm, resinous, slightly sweet accord (not true amber — a perfumery construct).'),
  ('Ambroxan', 'oriental', 'Warm, radiant amber-musk synthetic.');

-- 4. Brands -------------------------------------------------------------
insert into public.brands (name, country, founded_year) values
  ('Chanel', 'France', 1910),
  ('Dior', 'France', 1946),
  ('Tom Ford', 'USA', 2005),
  ('Yves Saint Laurent', 'France', 1961),
  ('Creed', 'France', 1760),
  ('Versace', 'Italy', 1978),
  ('Giorgio Armani', 'Italy', 1975),
  ('Jean Paul Gaultier', 'France', 1976),
  ('Marc Jacobs', 'USA', 1984),
  ('Dolce & Gabbana', 'Italy', 1985),
  ('Paco Rabanne', 'France', 1966),
  ('Guerlain', 'France', 1828),
  ('Hermès', 'France', 1837),
  ('Lancôme', 'France', 1935),
  ('Prada', 'Italy', 1913),
  ('Byredo', 'Sweden', 2006),
  ('Maison Margiela', 'France', 1988),
  ('Acqua di Parma', 'Italy', 1916);

-- 5. Fragrances ------------------------------------------------------------
insert into public.fragrances (brand_id, name, release_year, gender, concentration, description, longevity, sillage) values
  ((select id from public.brands where name = 'Chanel'), 'No. 5', 1921, 'feminine', 'edp',
    'The archetypal aldehydic floral — sparkling aldehydes over a bouquet of rose, jasmine and iris on a soft musky-woody base.', 4, 3),
  ((select id from public.brands where name = 'Dior'), 'Sauvage', 2015, 'masculine', 'edt',
    'A radiant, peppery-fresh scent built around ambroxan and vetiver — Dior''s modern signature.', 4, 4),
  ((select id from public.brands where name = 'Chanel'), 'Bleu de Chanel', 2010, 'masculine', 'edp',
    'A woody-aromatic scent that moves from citrus and mint through spice to a smoky cedar-sandalwood base.', 4, 4),
  ((select id from public.brands where name = 'Chanel'), 'Coco Mademoiselle', 2001, 'feminine', 'edp',
    'An oriental-floral chypre — citrus and orange blossom over rose and jasmine, on warm patchouli and vanilla.', 4, 3),
  ((select id from public.brands where name = 'Tom Ford'), 'Black Orchid', 2006, 'unisex', 'edp',
    'A luxurious, dark gourmand-floral built on black truffle, dark chocolate and incense.', 5, 4),
  ((select id from public.brands where name = 'Yves Saint Laurent'), 'Black Opium', 2014, 'feminine', 'edp',
    'A gourmand-oriental centered on a bold coffee-vanilla accord with a jasmine heart.', 4, 4),
  ((select id from public.brands where name = 'Creed'), 'Aventus', 2010, 'masculine', 'edp',
    'A fruity-chypre built around a smoky birch and pineapple accord — one of the most iconic modern niche releases.', 4, 4),
  ((select id from public.brands where name = 'Versace'), 'Eros', 2012, 'masculine', 'edt',
    'A sweet, minty-vanilla fougère with a bold tonka bean and ambroxan heart.', 4, 4),
  ((select id from public.brands where name = 'Giorgio Armani'), 'Acqua di Giò', 1996, 'masculine', 'edt',
    'The reference aquatic scent — marine calone and citrus over a warm woody-musk base.', 3, 3),
  ((select id from public.brands where name = 'Jean Paul Gaultier'), 'Le Male', 1995, 'masculine', 'edt',
    'A sweet oriental-fougère with a minty-lavender opening over vanilla and tonka bean.', 4, 4),
  ((select id from public.brands where name = 'Marc Jacobs'), 'Daisy', 2007, 'feminine', 'edt',
    'A light, fresh floral-fruity built on violet leaf, wild strawberry and white florals.', 2, 2),
  ((select id from public.brands where name = 'Dolce & Gabbana'), 'Light Blue', 2001, 'feminine', 'edt',
    'A crisp Mediterranean citrus-fruity scent with Sicilian lemon and apple.', 2, 2),
  ((select id from public.brands where name = 'Paco Rabanne'), '1 Million', 2008, 'masculine', 'edt',
    'A bold, sweet-spicy scent built around leather and amber under a citrus-mint opening.', 4, 4),
  ((select id from public.brands where name = 'Guerlain'), 'Shalimar', 1925, 'feminine', 'parfum',
    'The original modern oriental — bergamot and iris over a sensual vanilla-incense base.', 5, 4),
  ((select id from public.brands where name = 'Hermès'), 'Terre d''Hermès', 2006, 'masculine', 'edt',
    'A mineral, earthy-woody scent balancing citrus, pepper and flint over vetiver and cedar.', 4, 3),
  ((select id from public.brands where name = 'Lancôme'), 'La Vie Est Belle', 2012, 'feminine', 'edp',
    'A sweet, praline-iris gourmand-floral with a rich vanilla-patchouli base.', 5, 4),
  ((select id from public.brands where name = 'Prada'), 'Luna Rossa', 2012, 'masculine', 'edt',
    'A clean aromatic scent built on lavender and spearmint over ambroxan and cedar.', 3, 3),
  ((select id from public.brands where name = 'Byredo'), 'Gypsy Water', 2008, 'unisex', 'edp',
    'A bohemian woody-fresh scent — juniper and bergamot over incense, pine and sandalwood.', 3, 3),
  ((select id from public.brands where name = 'Maison Margiela'), 'Replica Jazz Club', 2013, 'unisex', 'edt',
    'A cozy, boozy-tobacco scent evoking rum and cigar smoke by a fireplace.', 3, 2),
  ((select id from public.brands where name = 'Acqua di Parma'), 'Colonia', 1916, 'unisex', 'edc',
    'A timeless Italian citrus cologne — Sicilian lemon and rose over sandalwood and vetiver.', 2, 2);

-- 6. Fragrance notes (pyramid) ---------------------------------------------
-- Helper pattern: for each fragrance, insert its top/middle/base notes by
-- name lookup. Written flat (one fragrance per block) for readability.

with f as (select id from public.fragrances where name = 'No. 5')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Aldehydes', 'top', 0), ('Neroli', 'top', 1), ('Ylang-Ylang', 'top', 2),
  ('Rose', 'middle', 0), ('Jasmine', 'middle', 1), ('Lily of the Valley', 'middle', 2), ('Iris', 'middle', 3),
  ('Sandalwood', 'base', 0), ('Vetiver', 'base', 1), ('Vanilla', 'base', 2), ('Musk', 'base', 3)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = 'Sauvage')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Bergamot', 'top', 0), ('Pepper', 'top', 1),
  ('Lavender', 'middle', 0), ('Pink Pepper', 'middle', 1), ('Geranium', 'middle', 2), ('Elemi', 'middle', 3),
  ('Ambroxan', 'base', 0), ('Cedar', 'base', 1), ('Labdanum', 'base', 2)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = 'Bleu de Chanel')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Grapefruit', 'top', 0), ('Lemon', 'top', 1), ('Mint', 'top', 2), ('Pink Pepper', 'top', 3),
  ('Ginger', 'middle', 0), ('Nutmeg', 'middle', 1), ('Jasmine', 'middle', 2),
  ('Incense', 'base', 0), ('Vetiver', 'base', 1), ('Cedar', 'base', 2), ('Sandalwood', 'base', 3), ('Patchouli', 'base', 4), ('Labdanum', 'base', 5)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = 'Coco Mademoiselle')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Orange', 'top', 0), ('Bergamot', 'top', 1), ('Orange Blossom', 'top', 2),
  ('Mimosa', 'middle', 0), ('Jasmine', 'middle', 1), ('Rose', 'middle', 2), ('Litchi', 'middle', 3),
  ('Patchouli', 'base', 0), ('Vetiver', 'base', 1), ('Vanilla', 'base', 2), ('Musk', 'base', 3), ('Opoponax', 'base', 4)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = 'Black Orchid')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Black Truffle', 'top', 0), ('Ylang-Ylang', 'top', 1), ('Bergamot', 'top', 2), ('Black Currant', 'top', 3),
  ('Orchid', 'middle', 0), ('Lotus', 'middle', 1), ('Nutmeg', 'middle', 2),
  ('Patchouli', 'base', 0), ('Sandalwood', 'base', 1), ('Dark Chocolate', 'base', 2), ('Incense', 'base', 3), ('Vanilla', 'base', 4)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = 'Black Opium')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Pink Pepper', 'top', 0), ('Orange Blossom', 'top', 1), ('Pear', 'top', 2),
  ('Coffee', 'middle', 0), ('Jasmine', 'middle', 1), ('Bitter Almond', 'middle', 2), ('Licorice', 'middle', 3),
  ('Vanilla', 'base', 0), ('Patchouli', 'base', 1), ('Cedar', 'base', 2)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = 'Aventus')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Pineapple', 'top', 0), ('Black Currant', 'top', 1), ('Green Apple', 'top', 2), ('Bergamot', 'top', 3),
  ('Birch', 'middle', 0), ('Patchouli', 'middle', 1), ('Moroccan Jasmine', 'middle', 2), ('Rose', 'middle', 3),
  ('Ambergris', 'base', 0), ('Musk', 'base', 1), ('Oakmoss', 'base', 2), ('Vanilla', 'base', 3)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = 'Eros')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Mint', 'top', 0), ('Green Apple', 'top', 1), ('Lemon', 'top', 2),
  ('Tonka Bean', 'middle', 0), ('Ambroxan', 'middle', 1), ('Geranium', 'middle', 2),
  ('Vanilla', 'base', 0), ('Vetiver', 'base', 1), ('Oakmoss', 'base', 2), ('Cedar', 'base', 3)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = 'Acqua di Giò')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Bergamot', 'top', 0), ('Neroli', 'top', 1), ('Green Mandarin', 'top', 2),
  ('Jasmine', 'middle', 0), ('Calone (Sea Notes)', 'middle', 1), ('Rosemary', 'middle', 2), ('Hyacinth', 'middle', 3),
  ('Musk', 'base', 0), ('Cedar', 'base', 1), ('Oakmoss', 'base', 2), ('Amber', 'base', 3)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = 'Le Male')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Mint', 'top', 0), ('Lavender', 'top', 1), ('Bergamot', 'top', 2), ('Cardamom', 'top', 3),
  ('Cinnamon', 'middle', 0), ('Orange Blossom', 'middle', 1),
  ('Vanilla', 'base', 0), ('Sandalwood', 'base', 1), ('Tonka Bean', 'base', 2), ('Amber', 'base', 3)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = 'Daisy')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Wild Strawberry', 'top', 0), ('Violet Leaf', 'top', 1), ('Grapefruit', 'top', 2),
  ('Violet', 'middle', 0), ('Jasmine', 'middle', 1), ('Gardenia', 'middle', 2),
  ('Musk', 'base', 0), ('Vanilla', 'base', 1), ('White Woods', 'base', 2)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = 'Light Blue')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Sicilian Lemon', 'top', 0), ('Green Apple', 'top', 1), ('Bluebell', 'top', 2),
  ('Bamboo', 'middle', 0), ('Jasmine', 'middle', 1), ('White Rose', 'middle', 2),
  ('Musk', 'base', 0), ('Cedar', 'base', 1), ('Amber', 'base', 2)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = '1 Million')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Blood Mandarin', 'top', 0), ('Mint', 'top', 1), ('Grapefruit', 'top', 2),
  ('Cinnamon', 'middle', 0), ('Rose', 'middle', 1),
  ('Leather', 'base', 0), ('Amber', 'base', 1), ('Patchouli', 'base', 2), ('White Woods', 'base', 3)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = 'Shalimar')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Bergamot', 'top', 0), ('Lemon', 'top', 1), ('Mandarin', 'top', 2),
  ('Iris', 'middle', 0), ('Jasmine', 'middle', 1), ('Rose', 'middle', 2),
  ('Opoponax', 'base', 0), ('Tonka Bean', 'base', 1), ('Vanilla', 'base', 2), ('Incense', 'base', 3), ('Civet', 'base', 4)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = 'Terre d''Hermès')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Orange', 'top', 0), ('Grapefruit', 'top', 1), ('Pepper', 'top', 2),
  ('Pelargonium', 'middle', 0), ('Flint', 'middle', 1),
  ('Vetiver', 'base', 0), ('Cedar', 'base', 1), ('Benzoin', 'base', 2), ('Oakmoss', 'base', 3)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = 'La Vie Est Belle')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Black Currant', 'top', 0), ('Pear', 'top', 1),
  ('Iris', 'middle', 0), ('Jasmine', 'middle', 1), ('Orange Blossom', 'middle', 2),
  ('Praline', 'base', 0), ('Vanilla', 'base', 1), ('Patchouli', 'base', 2), ('Tonka Bean', 'base', 3)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = 'Luna Rossa')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Lavender', 'top', 0), ('Bitter Orange', 'top', 1), ('Spearmint', 'top', 2),
  ('Myrtle', 'middle', 0),
  ('Ambroxan', 'base', 0), ('Virginia Cedar', 'base', 1)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = 'Gypsy Water')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Bergamot', 'top', 0), ('Lemon', 'top', 1), ('Pepper', 'top', 2), ('Juniper', 'top', 3),
  ('Incense', 'middle', 0), ('Pine Needles', 'middle', 1), ('Iris', 'middle', 2),
  ('Vanilla', 'base', 0), ('Sandalwood', 'base', 1), ('Amber', 'base', 2)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = 'Replica Jazz Club')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Pink Pepper', 'top', 0),
  ('Rum', 'middle', 0), ('Clary Sage', 'middle', 1),
  ('Tobacco Leaf', 'base', 0), ('Vanilla', 'base', 1), ('Styrax', 'base', 2)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

with f as (select id from public.fragrances where name = 'Colonia')
insert into public.fragrance_notes (fragrance_id, note_id, pyramid_level, position)
select f.id, n.id, v.level, v.pos
from f, (values
  ('Sicilian Lemon', 'top', 0), ('Bulgarian Rose', 'top', 1), ('Lavender', 'top', 2), ('Bergamot', 'top', 3),
  ('Rosemary', 'middle', 0), ('Verbena', 'middle', 1),
  ('Sandalwood', 'base', 0), ('Vetiver', 'base', 1), ('Patchouli', 'base', 2)
) as v(note_name, level, pos)
join public.notes n on n.name = v.note_name;

-- 7. Fragrance accords -------------------------------------------------------
with f as (select id from public.fragrances where name = 'No. 5')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('floral', 90), ('powdery', 70), ('musk', 45), ('aromatic', 35)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = 'Sauvage')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('spicy', 85), ('fresh', 75), ('woody', 60), ('citrus', 50), ('aromatic', 55)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = 'Bleu de Chanel')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('woody', 85), ('citrus', 70), ('aromatic', 60), ('spicy', 45)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = 'Coco Mademoiselle')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('chypre', 75), ('floral', 80), ('woody', 55), ('gourmand', 40)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = 'Black Orchid')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('gourmand', 80), ('oriental', 65), ('woody', 60), ('floral', 45)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = 'Black Opium')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('gourmand', 85), ('sweet', 70), ('vanilla', 60), ('floral', 40)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = 'Aventus')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('fruity', 80), ('woody', 65), ('smoky', 55), ('fresh', 50)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = 'Eros')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('sweet', 75), ('aromatic', 65), ('vanilla', 60), ('citrus', 45)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = 'Acqua di Giò')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('aquatic', 90), ('citrus', 65), ('aromatic', 55), ('fresh', 50)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = 'Le Male')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('sweet', 70), ('aromatic', 65), ('vanilla', 60), ('spicy', 40)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = 'Daisy')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('floral', 80), ('fruity', 60), ('white_floral', 55), ('powdery', 45)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = 'Light Blue')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('citrus', 85), ('fresh', 75), ('fruity', 55), ('woody', 35)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = '1 Million')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('amber', 75), ('leather', 65), ('sweet', 60), ('spicy', 50)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = 'Shalimar')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('oriental', 90), ('vanilla', 75), ('powdery', 55), ('amber', 50)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = 'Terre d''Hermès')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('woody', 85), ('citrus', 60), ('earthy', 55), ('fresh', 40)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = 'La Vie Est Belle')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('sweet', 85), ('gourmand', 75), ('vanilla', 65), ('floral', 55)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = 'Luna Rossa')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('aromatic', 80), ('fresh', 70), ('citrus', 45), ('woody', 40)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = 'Gypsy Water')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('woody', 75), ('amber', 55), ('fresh', 50), ('resin', 45)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = 'Replica Jazz Club')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('tobacco', 85), ('boozy', 65), ('sweet', 55), ('spicy', 35)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

with f as (select id from public.fragrances where name = 'Colonia')
insert into public.fragrance_accords (fragrance_id, accord_id, intensity)
select f.id, a.id, v.intensity from f, (values
  ('citrus', 85), ('aromatic', 65), ('fresh', 60), ('powdery', 40)
) as v(slug, intensity) join public.accords a on a.slug = v.slug;

-- 8. Fragrance seasons -------------------------------------------------------
with f as (select id from public.fragrances where name = 'No. 5')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',70),('summer',40),('fall',65),('winter',75)) as v(season, score);

with f as (select id from public.fragrances where name = 'Sauvage')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',80),('summer',75),('fall',70),('winter',55)) as v(season, score);

with f as (select id from public.fragrances where name = 'Bleu de Chanel')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',75),('summer',60),('fall',80),('winter',70)) as v(season, score);

with f as (select id from public.fragrances where name = 'Coco Mademoiselle')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',70),('summer',55),('fall',75),('winter',65)) as v(season, score);

with f as (select id from public.fragrances where name = 'Black Orchid')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',30),('summer',25),('fall',70),('winter',85)) as v(season, score);

with f as (select id from public.fragrances where name = 'Black Opium')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',30),('summer',20),('fall',75),('winter',85)) as v(season, score);

with f as (select id from public.fragrances where name = 'Aventus')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',75),('summer',65),('fall',80),('winter',60)) as v(season, score);

with f as (select id from public.fragrances where name = 'Eros')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',65),('summer',70),('fall',55),('winter',45)) as v(season, score);

with f as (select id from public.fragrances where name = 'Acqua di Giò')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',80),('summer',95),('fall',45),('winter',25)) as v(season, score);

with f as (select id from public.fragrances where name = 'Le Male')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',55),('summer',40),('fall',70),('winter',75)) as v(season, score);

with f as (select id from public.fragrances where name = 'Daisy')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',90),('summer',70),('fall',40),('winter',25)) as v(season, score);

with f as (select id from public.fragrances where name = 'Light Blue')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',85),('summer',90),('fall',35),('winter',20)) as v(season, score);

with f as (select id from public.fragrances where name = '1 Million')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',50),('summer',40),('fall',70),('winter',80)) as v(season, score);

with f as (select id from public.fragrances where name = 'Shalimar')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',35),('summer',20),('fall',75),('winter',90)) as v(season, score);

with f as (select id from public.fragrances where name = 'Terre d''Hermès')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',70),('summer',60),('fall',85),('winter',65)) as v(season, score);

with f as (select id from public.fragrances where name = 'La Vie Est Belle')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',55),('summer',35),('fall',75),('winter',80)) as v(season, score);

with f as (select id from public.fragrances where name = 'Luna Rossa')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',75),('summer',65),('fall',55),('winter',40)) as v(season, score);

with f as (select id from public.fragrances where name = 'Gypsy Water')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',65),('summer',55),('fall',70),('winter',60)) as v(season, score);

with f as (select id from public.fragrances where name = 'Replica Jazz Club')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',40),('summer',25),('fall',75),('winter',80)) as v(season, score);

with f as (select id from public.fragrances where name = 'Colonia')
insert into public.fragrance_seasons (fragrance_id, season, score)
select f.id, v.season, v.score from f, (values ('spring',80),('summer',85),('fall',45),('winter',30)) as v(season, score);

-- 9. Fragrance occasions -------------------------------------------------------
with f as (select id from public.fragrances where name = 'No. 5')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('formal', 90), ('office', 60), ('daily', 50), ('date_night', 70)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = 'Sauvage')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('daily', 90), ('office', 75), ('date_night', 70), ('gym', 40)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = 'Bleu de Chanel')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('office', 85), ('daily', 80), ('formal', 65), ('date_night', 60)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = 'Coco Mademoiselle')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('office', 70), ('date_night', 80), ('formal', 75), ('daily', 55)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = 'Black Orchid')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('night_out', 85), ('date_night', 80), ('formal', 60)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = 'Black Opium')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('night_out', 90), ('date_night', 75), ('festive', 60)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = 'Aventus')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('office', 80), ('daily', 70), ('formal', 70), ('date_night', 55)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = 'Eros')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('night_out', 80), ('date_night', 75), ('daily', 60), ('gym', 35)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = 'Acqua di Giò')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('daily', 85), ('beach', 90), ('office', 60), ('gym', 50)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = 'Le Male')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('date_night', 75), ('night_out', 70), ('daily', 55)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = 'Daisy')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('daily', 85), ('office', 70), ('beach', 55)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = 'Light Blue')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('daily', 90), ('beach', 85), ('office', 60)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = '1 Million')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('night_out', 85), ('date_night', 70), ('festive', 55)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = 'Shalimar')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('formal', 85), ('night_out', 70), ('date_night', 65)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = 'Terre d''Hermès')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('office', 85), ('daily', 75), ('formal', 60)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = 'La Vie Est Belle')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('formal', 70), ('date_night', 75), ('daily', 50)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = 'Luna Rossa')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('office', 80), ('daily', 75), ('gym', 45)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = 'Gypsy Water')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('daily', 70), ('travel', 75), ('cozy_home', 60)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = 'Replica Jazz Club')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('night_out', 75), ('cozy_home', 70), ('festive', 50)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

with f as (select id from public.fragrances where name = 'Colonia')
insert into public.fragrance_occasions (fragrance_id, occasion_id, score)
select f.id, o.id, v.score from f, (values
  ('daily', 85), ('office', 70), ('beach', 60)
) as v(slug, score) join public.occasions o on o.slug = v.slug;

-- 10. Occasion calendar ----------------------------------------------------
-- Fixed-date holidays set month/day directly; movable feasts (computed in
-- src/features/recommendations/occasions.ts) leave them null.
insert into public.occasion_calendar (slug, name, month, day, is_movable, occasion_id, lead_days) values
  ('valentines_day', 'Valentine''s Day', 2, 14, false, (select id from public.occasions where slug = 'date_night'), 5),
  ('new_years_eve', 'New Year''s Eve', 12, 31, false, (select id from public.occasions where slug = 'festive'), 3),
  ('christmas', 'Christmas Day', 12, 25, false, (select id from public.occasions where slug = 'festive'), 7),
  ('halloween', 'Halloween', 10, 31, false, (select id from public.occasions where slug = 'festive'), 3),
  ('new_years_day', 'New Year''s Day', 1, 1, false, (select id from public.occasions where slug = 'cozy_home'), 1),
  ('independence_day', 'Independence Day', 7, 4, false, (select id from public.occasions where slug = 'festive'), 3),
  ('mothers_day', 'Mother''s Day', null, null, true, (select id from public.occasions where slug = 'festive'), 5),
  ('fathers_day', 'Father''s Day', null, null, true, (select id from public.occasions where slug = 'festive'), 5),
  ('thanksgiving', 'Thanksgiving', null, null, true, (select id from public.occasions where slug = 'cozy_home'), 5),
  ('easter', 'Easter Sunday', null, null, true, (select id from public.occasions where slug = 'festive'), 5);

commit;
