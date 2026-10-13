-- Controlled Spanish catalog. Plurals and alternatives are explicit aliases,
-- never a generic singularizer that could conflate distinct ingredients.
insert into public.ingredients(id, canonical_name_es, approved)
select ('10000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid, name, true
from (values
  (1,'Tomate'), (2,'Cebolla'), (3,'Patata'), (4,'Huevo'), (5,'Ajo'),
  (6,'Aceite de oliva'), (7,'Aceite de girasol'), (8,'Sal'), (9,'Agua'),
  (10,'Arroz'), (11,'Harina de trigo'), (12,'Leche'), (13,'Mantequilla'),
  (14,'Zanahoria'), (15,'Calabacín'), (16,'Pimiento rojo'), (17,'Pimiento verde'),
  (18,'Pollo'), (19,'Ternera'), (20,'Cerdo'), (21,'Atún'), (22,'Salmón'),
  (23,'Lenteja'), (24,'Garbanzo'), (25,'Alubia blanca'), (26,'Espinaca'),
  (27,'Champiñón'), (28,'Limón'), (29,'Azúcar'), (30,'Yogur natural'),
  (31,'Pan'), (32,'Pasta'), (33,'Queso'), (34,'Perejil'), (35,'Pimienta negra'),
  (36,'Orégano'), (37,'Vinagre'), (38,'Lechuga'), (39,'Pepino'), (40,'Manzana'),
  (41,'Plátano'), (42,'Nata'), (43,'Berenjena'), (44,'Brócoli'), (45,'Coliflor'),
  (46,'Comino'), (47,'Pimentón dulce'), (48,'Pimentón picante'), (49,'Guisante'),
  (50,'Judía verde')
) as catalog(n, name);

insert into public.ingredient_aliases(ingredient_id, alias_es)
select ('10000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid, alias
from (values
  (1,'Tomates'), (2,'Cebollas'), (3,'Patatas'), (4,'Huevos'), (5,'Ajos'),
  (6,'AOVE'), (6,'Aceite de oliva virgen extra'), (14,'Zanahorias'),
  (15,'Calabacines'), (16,'Pimientos rojos'), (17,'Pimientos verdes'),
  (23,'Lentejas'), (24,'Garbanzos'), (25,'Alubias blancas'), (26,'Espinacas'),
  (27,'Champiñones'), (28,'Limones'), (30,'Yogures naturales'), (33,'Quesos'),
  (40,'Manzanas'), (41,'Plátanos'), (43,'Berenjenas'), (49,'Guisantes'), (50,'Judías verdes')
) as aliases(n, alias);
-- No aliases for ambiguous "aceite", "harina" or "pimiento"; no equivalence
-- between milk and cream, or between red/green pepper or sweet/hot paprika.
