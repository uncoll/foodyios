import Foundation

/// Инструкция и JSON-схема для распознавания этикетки. Тот же текст используется в бенчмарке
/// (`tools/label-bench/prompt.txt`, `schema.json`) — файлы генерируются из одного источника.
public enum LabelParseSpec {
    /// Инструкция модели (английский — модели надёжнее следуют ему; этикетка может быть на любом языке).
    public static let instruction: String = #"""
You are a precise nutrition-label reader. The image shows the nutrition declaration printed on a food package (Nährwerte / Valeurs nutritionnelles / Valori nutrizionali / Información nutricional / Wartość odżywcza / Voedingswaarde / Пищевая ценность / Nutrition facts, etc.). It may be in any language and may contain several columns.

Extract the values into the JSON schema provided.

Rules:
1. Report values PER 100 g or PER 100 ml exactly as printed in the "per 100 g / 100 ml" column and set "basis" accordingly. Ignore percentage columns (% RI, % NRV, % of reference intake, % РСП).
2. If the label has both a per-100 column and a per-serving/per-portion column, use the per-100 column and set values_source = "per_100_column". If ONLY per-serving values are printed and the serving size in g/ml is stated, convert to per 100 (value × 100 / serving size) and set values_source = "converted_from_serving". If no conversion is possible, return null for the values and set values_source = "unclear".
3. Copy numbers exactly as printed (a decimal comma is a decimal point). Do not round, do not compute values that are not printed, do not fill in values from memory or from knowledge of the product. A row that is not printed → null.
4. Values printed as "<0.5", "< 0,1", "traces", "Spuren" → return the numeric upper bound (e.g. 0.5) and mention it in notes.
5. Energy: fill both energy_kcal and energy_kj when both are printed. Fat: "of which saturates" → saturated_fat_g; mono-/polyunsaturates and trans fat only if printed. Carbohydrates: "of which sugars" → sugars_g; polyols and starch only if printed. Fibre → fiber_g. Protein → protein_g. Salt → salt_g. If the label prints sodium instead of salt, fill sodium_mg (convert g to mg) and leave salt_g null.
6. serving_size_g: the stated portion size in g or ml (number only); serving_description: the portion as printed (e.g. "1 portion (30 g)").
7. product_name and brand: only if visible in the photo, otherwise null.
8. micronutrients: vitamin and mineral rows with numeric amount and unit as printed; name in English lowercase snake_case (vitamin_c, vitamin_d, calcium, iron, ...). Empty array if none.
9. confidence: "high" if all main rows are clearly readable, "medium" if some digits were hard to read, "low" if the image is blurry, cut off or is not a nutrition table. Put any doubts in notes (short, English).
Return only the JSON object.
"""#

    /// JSON Schema результата (strict-совместимая: все поля обязательны, additionalProperties = false).
    public static let schemaJSON: String = #"""
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "product_name",
    "brand",
    "basis",
    "serving_size_g",
    "serving_description",
    "energy_kcal",
    "energy_kj",
    "fat_g",
    "saturated_fat_g",
    "monounsaturated_fat_g",
    "polyunsaturated_fat_g",
    "trans_fat_g",
    "cholesterol_mg",
    "carbohydrates_g",
    "sugars_g",
    "polyols_g",
    "starch_g",
    "fiber_g",
    "protein_g",
    "salt_g",
    "sodium_mg",
    "alcohol_g",
    "micronutrients",
    "label_language",
    "values_source",
    "notes",
    "confidence"
  ],
  "properties": {
    "product_name": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "description": "Product name if visible in the photo, else null"
    },
    "brand": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "description": "Brand if visible, else null"
    },
    "basis": {
      "type": "string",
      "enum": [
        "per_100g",
        "per_100ml"
      ],
      "description": "Whether the values are per 100 g or per 100 ml"
    },
    "serving_size_g": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ],
      "description": "Stated serving/portion size in g or ml, number only"
    },
    "serving_description": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "description": "Serving as printed, e.g. '1 portion (30 g)'"
    },
    "energy_kcal": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ]
    },
    "energy_kj": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ]
    },
    "fat_g": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ]
    },
    "saturated_fat_g": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ]
    },
    "monounsaturated_fat_g": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ]
    },
    "polyunsaturated_fat_g": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ]
    },
    "trans_fat_g": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ]
    },
    "cholesterol_mg": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ]
    },
    "carbohydrates_g": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ]
    },
    "sugars_g": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ]
    },
    "polyols_g": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ]
    },
    "starch_g": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ]
    },
    "fiber_g": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ]
    },
    "protein_g": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ]
    },
    "salt_g": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ]
    },
    "sodium_mg": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ]
    },
    "alcohol_g": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ]
    },
    "micronutrients": {
      "type": "array",
      "description": "Vitamins and minerals rows as printed",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "name",
          "amount",
          "unit"
        ],
        "properties": {
          "name": {
            "type": "string",
            "description": "English lowercase snake_case, e.g. vitamin_c, calcium, iron"
          },
          "amount": {
            "type": "number"
          },
          "unit": {
            "type": "string",
            "description": "Unit as printed: mg, µg, g"
          }
        }
      }
    },
    "label_language": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "description": "ISO 639-1 code of the label language, e.g. de, fr, ru"
    },
    "values_source": {
      "type": "string",
      "enum": [
        "per_100_column",
        "converted_from_serving",
        "unclear"
      ]
    },
    "notes": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "description": "Short English notes about doubts, '<0.5' values, conversions"
    },
    "confidence": {
      "type": "string",
      "enum": [
        "high",
        "medium",
        "low"
      ]
    }
  }
}
"""#

    /// Схема как объект для вставки в тело запроса.
    public static var schemaObject: [String: Any] {
        let data = Data(schemaJSON.utf8)
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    /// Имя схемы для OpenAI (`text.format.name`).
    public static let schemaName = "nutrition_label"
}
