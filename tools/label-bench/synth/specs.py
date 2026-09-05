"""Описания синтетических этикеток: значения (эталон) + параметры вёрстки и «фотографической» деградации.

Каждая спека: id, lang, basis, values (per 100), rows (как печатать), layout, style, degrade.
Эталон для скоринга берётся из values; поля, которых нет на этикетке, отмечаются как "absent".
"""

FIELDS = ["energy_kcal", "energy_kj", "fat_g", "saturated_fat_g", "monounsaturated_fat_g", "polyunsaturated_fat_g",
          "carbohydrates_g", "sugars_g", "polyols_g", "starch_g", "fiber_g", "protein_g", "salt_g"]


def fmt(v, lang):
    """Число как на этикетке: запятая для континентальных языков, точка для en."""
    if isinstance(v, str):
        return v
    if isinstance(v, int) or (isinstance(v, float) and v.is_integer() and v >= 100):
        s = str(int(v))
    elif isinstance(v, float) and v.is_integer():
        s = f"{v:.1f}"
    else:
        s = f"{v:g}"
    return s if lang == "en" else s.replace(".", ",")


SPECS = [
    dict(id="s01_de_oats", lang="de", basis="per_100g", product="Haferflocken",
         title="Nährwerte", head=["pro 100 g"],
         values=dict(energy_kj=1560, energy_kcal=372, fat_g=7.0, saturated_fat_g=1.3, carbohydrates_g=58.7, sugars_g=0.7,
                     fiber_g=10.0, protein_g=13.5, salt_g={"lt": 0.01}),
         rows=[("Brennwert", ["{energy_kj} kJ / {energy_kcal} kcal"]), ("Fett", ["{fat_g} g"]),
               ("  davon gesättigte Fettsäuren", ["{saturated_fat_g} g"]), ("Kohlenhydrate", ["{carbohydrates_g} g"]),
               ("  davon Zucker", ["{sugars_g} g"]), ("Ballaststoffe", ["{fiber_g} g"]), ("Eiweiß", ["{protein_g} g"]),
               ("Salz", ["<0,01 g"])],
         style=dict(font="Liberation Sans", size=15, bg="#f7f3e8", fg="#1a1a1a", width=520, border=True),
         degrade=dict(perspective=0.05, rotate=-2, blur=0.6, noise=4, jpeg=80, scale=0.9, shade=0.3)),

    dict(id="s02_fr_biscuits", lang="fr", basis="per_100g", product="Biscuits",
         title="Valeurs nutritionnelles moyennes", head=["pour 100 g", "par biscuit (12,5 g)", "%AR* par biscuit"],
         values=dict(energy_kj=1985, energy_kcal=473, fat_g=17, saturated_fat_g=8.2, carbohydrates_g=70, sugars_g=25,
                     fiber_g=2.5, protein_g=6.6, salt_g=0.80),
         rows=[("Énergie", ["{energy_kj} kJ / {energy_kcal} kcal", "248 kJ / 59 kcal", "3 %"]),
               ("Matières grasses", ["{fat_g} g", "2,1 g", "3 %"]),
               ("  dont acides gras saturés", ["{saturated_fat_g} g", "1,0 g", "5 %"]),
               ("Glucides", ["{carbohydrates_g} g", "8,8 g", "3 %"]), ("  dont sucres", ["{sugars_g} g", "3,1 g", "3 %"]),
               ("Fibres alimentaires", ["{fiber_g} g", "0,3 g", "–"]), ("Protéines", ["{protein_g} g", "0,8 g", "2 %"]),
               ("Sel", ["0,80 g", "0,10 g", "2 %"])],
         footer="*Apport de référence pour un adulte-type (8400 kJ / 2000 kcal). Portion : 1 biscuit (12,5 g). Paquet : 20 biscuits.",
         serving_g=12.5,
         style=dict(font="DejaVu Sans", size=13, bg="#fff8ea", fg="#222", width=680, border=True),
         degrade=dict(perspective=0.03, rotate=-4, blur=0.7, noise=5, jpeg=75, scale=0.85, shade=0.5)),

    dict(id="s03_it_drink", lang="it", basis="per_100ml", product="Bevanda",
         title="Dichiarazione nutrizionale", head=["per 100 ml"],
         values=dict(energy_kj=180, energy_kcal=43, fat_g=0, saturated_fat_g=0, carbohydrates_g=10.5, sugars_g=10.5,
                     fiber_g="absent", protein_g=0, salt_g=0.01),
         rows=[("Energia", ["{energy_kj} kJ / {energy_kcal} kcal"]), ("Grassi", ["0 g"]),
               ("  di cui acidi grassi saturi", ["0 g"]), ("Carboidrati", ["{carbohydrates_g} g"]),
               ("  di cui zuccheri", ["{sugars_g} g"]), ("Proteine", ["0 g"]), ("Sale", ["{salt_g} g"])],
         style=dict(font="Liberation Sans", size=14, bg="#0b2a5b", fg="#ffffff", width=420, border=True, border_color="#ffffff"),
         degrade=dict(cylinder=0.55, rotate=1, blur=0.8, noise=6, jpeg=78, scale=0.9, glare=0.5, shade=0.4)),

    dict(id="s04_es_yogur", lang="es", basis="per_100g", product="Yogur",
         title="Información nutricional", head=["por 100 g", "por envase (125 g)"],
         values=dict(energy_kj=395, energy_kcal=94, fat_g=3.0, saturated_fat_g=2.0, carbohydrates_g=12.8, sugars_g=12.2,
                     fiber_g="absent", protein_g=3.7, salt_g=0.13),
         rows=[("Valor energético", ["{energy_kj} kJ / {energy_kcal} kcal", "494 kJ / 118 kcal"]),
               ("Grasas", ["{fat_g} g", "3,8 g"]), ("  de las cuales saturadas", ["{saturated_fat_g} g", "2,5 g"]),
               ("Hidratos de carbono", ["{carbohydrates_g} g", "16 g"]), ("  de los cuales azúcares", ["{sugars_g} g", "15,3 g"]),
               ("Proteínas", ["{protein_g} g", "4,6 g"]), ("Sal", ["{salt_g} g", "0,16 g"])],
         serving_g=125,
         style=dict(font="FreeSans", size=14, bg="#fbe9ee", fg="#3a1f2b", width=560, border=False, zebra=True),
         degrade=dict(perspective=0.04, rotate=2, blur=0.5, noise=3, jpeg=85, scale=0.95, shade=0.25)),

    dict(id="s05_pl_bread", lang="pl", basis="per_100g", product="Chleb",
         title="Wartość odżywcza", head=["w 100 g"],
         values=dict(energy_kj=1040, energy_kcal=247, fat_g=1.8, saturated_fat_g=0.4, carbohydrates_g=46, sugars_g=3.2,
                     fiber_g=6.1, protein_g=8.5, salt_g=1.2),
         rows=[("Wartość energetyczna", ["{energy_kj} kJ / {energy_kcal} kcal"]), ("Tłuszcz", ["{fat_g} g"]),
               ("  w tym kwasy tłuszczowe nasycone", ["{saturated_fat_g} g"]), ("Węglowodany", ["{carbohydrates_g} g"]),
               ("  w tym cukry", ["{sugars_g} g"]), ("Błonnik", ["{fiber_g} g"]), ("Białko", ["{protein_g} g"]), ("Sól", ["{salt_g} g"])],
         style=dict(font="Liberation Sans", size=13, bg="#c9a66b", fg="#2b1d0e", width=500, border=True, border_color="#2b1d0e"),
         degrade=dict(perspective=0.03, rotate=-1, blur=1.3, noise=9, jpeg=60, scale=0.55, shade=0.35)),

    dict(id="s06_nl_pindakaas", lang="nl", basis="per_100g", product="Pindakaas",
         title="Voedingswaarde", head=["per 100 g"],
         values=dict(energy_kj=2620, energy_kcal=632, fat_g=52, saturated_fat_g=9.0, monounsaturated_fat_g=25,
                     polyunsaturated_fat_g=16, carbohydrates_g=12, sugars_g=6.5, fiber_g=7.5, protein_g=25, salt_g=1.1),
         rows=[("Energie", ["{energy_kj} kJ / {energy_kcal} kcal"]), ("Vetten", ["{fat_g} g"]),
               ("  waarvan verzadigd", ["{saturated_fat_g} g"]), ("  waarvan enkelvoudig onverzadigd", ["{monounsaturated_fat_g} g"]),
               ("  waarvan meervoudig onverzadigd", ["{polyunsaturated_fat_g} g"]), ("Koolhydraten", ["{carbohydrates_g} g"]),
               ("  waarvan suikers", ["{sugars_g} g"]), ("Vezels", ["{fiber_g} g"]), ("Eiwitten", ["{protein_g} g"]), ("Zout", ["{salt_g} g"])],
         style=dict(font="DejaVu Sans", size=14, bg="#ffffff", fg="#111", width=520, border=True),
         degrade=dict(perspective=0.10, rotate=3, blur=0.6, noise=4, jpeg=80, scale=0.9, shade=0.4)),

    dict(id="s07_cs_cheese", lang="cs", basis="per_100g", product="Sýr",
         title="Výživové údaje", head=["ve 100 g"],
         values=dict(energy_kj=1380, energy_kcal=332, fat_g=27, saturated_fat_g=18, carbohydrates_g=1.5, sugars_g=0.5,
                     fiber_g="absent", protein_g=21, salt_g=1.7),
         rows=[("Energie", ["{energy_kj} kJ / {energy_kcal} kcal"]), ("Tuky", ["{fat_g} g"]),
               ("  z toho nasycené mastné kyseliny", ["{saturated_fat_g} g"]), ("Sacharidy", ["{carbohydrates_g} g"]),
               ("  z toho cukry", ["{sugars_g} g"]), ("Bílkoviny", ["{protein_g} g"]), ("Sůl", ["{salt_g} g"])],
         style=dict(font="Liberation Sans", size=11, bg="#f2f2f2", fg="#000", width=380, border=True),
         degrade=dict(perspective=0.02, rotate=0.5, blur=0.7, noise=5, jpeg=70, scale=0.7, shade=0.2)),

    dict(id="s08_ru_inline", lang="ru", basis="per_100g", product="Печенье",
         inline=("Пищевая ценность в 100 г продукта: белки – 7,5 г, жиры – 18,0 г, углеводы – 66,0 г. "
                 "Энергетическая ценность – 456 ккал / 1910 кДж. Состав: мука пшеничная, сахар, масло растительное, "
                 "яйцо, разрыхлитель, соль, ароматизатор. Хранить при температуре не выше +25 °C."),
         values=dict(energy_kj=1910, energy_kcal=456, fat_g=18.0, saturated_fat_g="absent", carbohydrates_g=66.0,
                     sugars_g="absent", fiber_g="absent", protein_g=7.5, salt_g="absent"),
         style=dict(font="DejaVu Sans", size=13, bg="#fdf6e3", fg="#222", width=560, border=False),
         degrade=dict(perspective=0.03, rotate=3, blur=0.8, noise=5, jpeg=75, scale=0.85, shade=0.3)),

    dict(id="s09_ru_table", lang="ru", basis="per_100g", product="Каша",
         title="Пищевая ценность на 100 г продукта", head=[""],
         values=dict(energy_kj=1470, energy_kcal=350, fat_g=6.5, saturated_fat_g=1.2, carbohydrates_g=60.0, sugars_g=1.0,
                     fiber_g=9.0, protein_g=11.0, salt_g=0.02),
         rows=[("Энергетическая ценность", ["{energy_kj} кДж / {energy_kcal} ккал"]), ("Белки", ["{protein_g} г"]),
               ("Жиры", ["{fat_g} г"]), ("  в т.ч. насыщенные", ["{saturated_fat_g} г"]), ("Углеводы", ["{carbohydrates_g} г"]),
               ("  в т.ч. сахара", ["{sugars_g} г"]), ("Пищевые волокна", ["{fiber_g} г"]), ("Соль", ["{salt_g} г"])],
         style=dict(font="Liberation Sans", size=14, bg="#e8f1dc", fg="#1e2d14", width=520, border=True),
         degrade=dict(perspective=0.04, rotate=-2, blur=0.5, noise=4, jpeg=82, scale=0.9, shade=0.6)),

    dict(id="s10_en_cereal", lang="en", basis="per_100g", product="Cereal",
         title="Typical values", head=["per 100 g", "per 30 g serving", "RI* per serving"],
         values=dict(energy_kj=1620, energy_kcal=383, fat_g=2.3, saturated_fat_g=0.5, carbohydrates_g=76, sugars_g=21,
                     fiber_g=7.1, protein_g=8.0, salt_g=0.90),
         rows=[("Energy", ["{energy_kj} kJ / {energy_kcal} kcal", "486 kJ / 115 kcal", "6%"]),
               ("Fat", ["{fat_g} g", "0.7 g", "1%"]), ("  of which saturates", ["{saturated_fat_g} g", "0.2 g", "1%"]),
               ("Carbohydrate", ["{carbohydrates_g} g", "23 g", "9%"]), ("  of which sugars", ["{sugars_g} g", "6.3 g", "7%"]),
               ("Fibre", ["{fiber_g} g", "2.1 g", "–"]), ("Protein", ["{protein_g} g", "2.4 g", "5%"]),
               ("Salt", ["0.90 g", "0.27 g", "5%"]),
               ("Vitamin D", ["4.2 µg", "1.3 µg", "25%"]), ("Thiamin (B1)", ["1.1 mg", "0.33 mg", "30%"]),
               ("Riboflavin (B2)", ["1.4 mg", "0.42 mg", "30%"]), ("Niacin", ["16 mg", "4.8 mg", "30%"]),
               ("Vitamin B6", ["1.4 mg", "0.42 mg", "30%"]), ("Folic acid", ["200 µg", "60 µg", "30%"]),
               ("Vitamin B12", ["2.5 µg", "0.75 µg", "30%"]), ("Iron", ["8.0 mg", "2.4 mg", "17%"])],
         footer="*Reference intake of an average adult (8400 kJ / 2000 kcal).",
         serving_g=30,
         style=dict(font="Liberation Sans", size=12, bg="#ffffff", fg="#111", width=640, border=True, zebra=True),
         degrade=dict(perspective=0.05, rotate=1.5, blur=0.6, noise=4, jpeg=80, scale=0.9, shade=0.3)),

    dict(id="s11_de_chocolate", lang="de", basis="per_100g", product="Schokolade",
         title="Nährwertangaben", head=["je 100 g", "je Portion (25 g)"],
         values=dict(energy_kj=2280, energy_kcal=547, fat_g=33, saturated_fat_g=20, carbohydrates_g=52, sugars_g=49,
                     fiber_g="absent", protein_g=6.4, salt_g=0.20),
         rows=[("Energie", ["{energy_kj} kJ / {energy_kcal} kcal", "570 kJ / 137 kcal"]), ("Fett", ["{fat_g} g", "8,3 g"]),
               ("  davon gesättigte Fettsäuren", ["{saturated_fat_g} g", "5,0 g"]), ("Kohlenhydrate", ["{carbohydrates_g} g", "13 g"]),
               ("  davon Zucker", ["{sugars_g} g", "12 g"]), ("Eiweiß", ["{protein_g} g", "1,6 g"]), ("Salz", ["0,20 g", "0,05 g"])],
         serving_g=25,
         style=dict(font="DejaVu Sans", size=13, bg="#3a1d10", fg="#f3e6c8", width=560, border=True, border_color="#f3e6c8"),
         degrade=dict(cylinder=0.35, rotate=-1, blur=0.7, noise=6, jpeg=75, scale=0.9, glare=0.6, shade=0.5)),

    dict(id="s12_fr_soup_hard", lang="fr", basis="per_100ml", product="Soupe",
         title="Valeurs nutritionnelles", head=["pour 100 ml"],
         values=dict(energy_kj=143, energy_kcal=34, fat_g=1.1, saturated_fat_g=0.2, carbohydrates_g=5.0, sugars_g=2.4,
                     fiber_g=0.9, protein_g=1.0, salt_g=0.6),
         rows=[("Énergie", ["{energy_kj} kJ / {energy_kcal} kcal"]), ("Matières grasses", ["{fat_g} g"]),
               ("  dont acides gras saturés", ["{saturated_fat_g} g"]), ("Glucides", ["{carbohydrates_g} g"]),
               ("  dont sucres", ["{sugars_g} g"]), ("Fibres alimentaires", ["{fiber_g} g"]), ("Protéines", ["{protein_g} g"]), ("Sel", ["{salt_g} g"])],
         style=dict(font="Liberation Sans", size=13, bg="#e7efe0", fg="#22301a", width=480, border=True),
         degrade=dict(perspective=0.06, rotate=-3, blur=1.9, noise=12, jpeg=45, scale=0.6, shade=0.5)),

    dict(id="s13_it_pasta", lang="it", basis="per_100g", product="Pasta",
         title="Valori medi", head=["per 100 g", "per porzione (80 g)"],
         values=dict(energy_kj=1521, energy_kcal=359, fat_g=1.5, saturated_fat_g=0.3, carbohydrates_g=71, sugars_g=3.5,
                     fiber_g=3.0, protein_g=13, salt_g=0.013),
         rows=[("Energia", ["{energy_kj} kJ / {energy_kcal} kcal", "1217 kJ / 287 kcal"]), ("Grassi", ["{fat_g} g", "1,2 g"]),
               ("  di cui acidi grassi saturi", ["{saturated_fat_g} g", "0,2 g"]), ("Carboidrati", ["{carbohydrates_g} g", "57 g"]),
               ("  di cui zuccheri", ["{sugars_g} g", "2,8 g"]), ("Fibre", ["{fiber_g} g", "2,4 g"]),
               ("Proteine", ["{protein_g} g", "10 g"]), ("Sale", ["0,013 g", "0,010 g"])],
         serving_g=80,
         style=dict(font="FreeSans", size=14, bg="#fff3d6", fg="#1c1c1c", width=560, border=True),
         degrade=dict(perspective=0.02, rotate=2.5, blur=0.5, noise=3, jpeg=85, scale=1.0, shade=0.2)),

    dict(id="s14_es_oil", lang="es", basis="per_100ml", product="Aceite de oliva",
         title="Información nutricional", head=["por 100 ml"],
         values=dict(energy_kj=3389, energy_kcal=824, fat_g=91.6, saturated_fat_g=14, monounsaturated_fat_g=69,
                     polyunsaturated_fat_g=8.6, carbohydrates_g=0, sugars_g=0, fiber_g="absent", protein_g=0, salt_g=0),
         rows=[("Valor energético", ["{energy_kj} kJ / {energy_kcal} kcal"]), ("Grasas", ["{fat_g} g"]),
               ("  de las cuales saturadas", ["{saturated_fat_g} g"]), ("  monoinsaturadas", ["{monounsaturated_fat_g} g"]),
               ("  poliinsaturadas", ["{polyunsaturated_fat_g} g"]), ("Hidratos de carbono", ["0 g"]),
               ("  de los cuales azúcares", ["0 g"]), ("Proteínas", ["0 g"]), ("Sal", ["0 g"])],
         style=dict(font="Liberation Sans", size=13, bg="#dfe7b0", fg="#2b3a12", width=440, border=True),
         degrade=dict(cylinder=0.6, rotate=0, blur=0.7, noise=5, jpeg=78, scale=0.85, glare=0.4, shade=0.4, tint=(0.95, 1.0, 0.8))),
]


def html_for(spec):
    st = spec["style"]
    lang = spec["lang"]
    border = f"1px solid {st.get('border_color', st['fg'])}" if st.get("border") else "none"
    css = f"""
    body {{ margin: 0; background: {st['bg']}; }}
    #label {{ display: inline-block; padding: 18px 22px; background: {st['bg']}; color: {st['fg']};
              font-family: '{st['font']}', sans-serif; font-size: {st['size']}px; width: {st['width']}px; box-sizing: border-box; }}
    table {{ border-collapse: collapse; width: 100%; border: {border}; }}
    th, td {{ padding: 3px 6px; border-bottom: {border}; text-align: right; white-space: nowrap; }}
    th {{ font-weight: bold; }}
    td:first-child, th:first-child {{ text-align: left; white-space: normal; }}
    tr.sub td:first-child {{ padding-left: 18px; font-weight: normal; }}
    tr.main td:first-child {{ font-weight: bold; }}
    tr.zebra {{ background: rgba(0,0,0,0.05); }}
    .title {{ font-weight: bold; font-size: {st['size'] + 2}px; margin-bottom: 6px; }}
    .footer {{ font-size: {max(st['size'] - 3, 8)}px; margin-top: 8px; }}
    p.inline {{ line-height: 1.35; margin: 0; text-align: justify; }}
    """
    body = []
    if spec.get("inline"):
        body.append(f"<p class='inline'>{spec['inline']}</p>")
    else:
        vals = {k: fmt(v, lang) if not isinstance(v, (dict, str)) else "" for k, v in spec["values"].items()}
        body.append(f"<div class='title'>{spec['title']}</div>")
        head = "".join(f"<th>{h}</th>" for h in spec["head"])
        body.append(f"<table><tr><th></th>{head}</tr>")
        for i, (name, cells) in enumerate(spec["rows"]):
            sub = name.startswith("  ")
            cls = "sub" if sub else "main"
            if st.get("zebra") and i % 2 == 1:
                cls += " zebra"
            tds = "".join(f"<td>{c.format(**vals)}</td>" for c in cells)
            body.append(f"<tr class='{cls}'><td>{name.strip()}</td>{tds}</tr>")
        body.append("</table>")
        if spec.get("footer"):
            body.append(f"<div class='footer'>{spec['footer']}</div>")
    return f"<!doctype html><html><head><meta charset='utf-8'><style>{css}</style></head><body><div id='label'>{''.join(body)}</div></body></html>"
