"""
python manage.py seed_skin_conditions

Fills the 8 SkinCondition records that exactly match the class_names from
skin_disease_training.ipynb (UNIFIED_CLASSES). Run this ONCE, before you
first test the /api/analyses/scan-skin/ endpoint - otherwise the AI will
return a condition_key that doesn't exist in the database and you'll get
a 404 (same as in leafscan when Plant/Disease doesn't exist in the table).

The symptoms and `treatment_overview` fields are general, educational
information (largely consistent with what sources like Mayo Clinic /
DermNet describe) - NOT personalized medical advice, and they don't
mention specific medications/doses. Always review/adjust them through the
Django admin or React admin panel before production use (ideally, verified
by a dermatologist).
"""

from django.core.management.base import BaseCommand

from core.models import SkinCondition, Severity, ConditionCategory


CONDITIONS = [
    {
        "key": "melanoma",
        "name": "Melanoma",
        "severity": Severity.HIGH,
        "category": ConditionCategory.MALIGNANT,
        "description": "Малигна лезија на пигментните клетки на кожата. Бара итен преглед кај дерматолог.",
        "symptoms": (
            "Младеж или дамка што е асиметрична, со неправилни/замаглени рабови, "
            "со повеќе бои во иста лезија (кафеава, црна, розева, сина), пречник "
            "поголем од 6мм, и/или се менува во големина, облик или боја со текот "
            "на времето. Може да чеша, крвави или да не заздравува."
        ),
        "treatment_overview": (
            "Дерматолозите најчесто ја отстрануваат лезијата хируршки (ексцизија), "
            "понекогаш со проверка на најблиските лимфни јазли. Кај понапредни "
            "случаи, третманот може да вклучи имунотерапија или таргетирана "
            "терапија. Точниот пристап зависи од длабочината и стадиумот и го "
            "одредува дерматолог/онколог по биопсија."
        ),
    },
    {
        "key": "basal_cell_carcinoma",
        "name": "Basal Cell Carcinoma",
        "severity": Severity.HIGH,
        "category": ConditionCategory.MALIGNANT,
        "description": "Најчест тип на кожен карцином, бавно расте, но бара медицинска дијагноза и третман.",
        "symptoms": (
            "Сјаен/восочен испакнат чвор, рамна лузна-слична лезија со кафеава или "
            "телесна боја, или рана што крвави, коричи и потоа заздравува па пак "
            "се враќа. Најчесто на делови изложени на сонце (лице, уши, врат)."
        ),
        "treatment_overview": (
            "Обично се третира со хируршко отстранување (вклучувајќи Mohs хирургија "
            "за прецизно чување на здраво ткиво). Помали лезии понекогаш се третираат "
            "со криотерапија, топикална терапија или радиотерапија. Изборот го прави "
            "дерматолог според големината и локацијата."
        ),
    },
    {
        "key": "squamous_cell_carcinoma",
        "name": "Squamous Cell Carcinoma",
        "severity": Severity.HIGH,
        "category": ConditionCategory.MALIGNANT,
        "description": "Малигна лезија на плочестите клетки на кожата. Бара медицинска проценка.",
        "symptoms": (
            "Цврст црвеникав чвор, рамна лезија со лушпеста/крастава површина, или "
            "рана/язва што не заздравува со месеци. Може да личи и на брадавица. "
            "Најчесто на делови изложени на сонце."
        ),
        "treatment_overview": (
            "Најчест пристап е хируршко отстранување (ексцизија или Mohs хирургија); "
            "кај поголеми или тешко достапни лезии може да се препорача радиотерапија. "
            "Конечната одлука ја носи дерматолог/онколог по проценка на стадиумот."
        ),
    },
    {
        "key": "actinic_keratosis",
        "name": "Actinic Keratosis",
        "severity": Severity.MEDIUM,
        "category": ConditionCategory.PRECANCEROUS,
        "description": "Прекарцинозна промена предизвикана од долготрајно изложување на сонце.",
        "symptoms": (
            "Груба, сува, лушпеста дамка (обично под 2см), розева, црвеникава или "
            "кафеава, на кожа изложена на сонце (лице, скалп, раце). Може да чеша "
            "или пецка, а понекогаш е полесно да се почувствува отколку да се види."
        ),
        "treatment_overview": (
            "Дерматолозите вообичаено користат криотерапија (замрзнување), топикална "
            "терапија или фотодинамична терапија, во зависност од бројот и локацијата "
            "на лезиите. Без третман, мал процент можат да прогресираат кон squamous "
            "cell carcinoma, затоа се препорачува преглед."
        ),
    },
    {
        "key": "seborrheic_keratosis",
        "name": "Seborrheic Keratosis",
        "severity": Severity.LOW,
        "category": ConditionCategory.BENIGN,
        "description": "Доброќудна брадавичеста промена на кожата, честа кај постари лица.",
        "symptoms": (
            "Восочна, „залепена” дамка со остар раб, кафеава/црна/бежова боја, "
            "тркалезна или овална, со малку рапава/брадавичеста површина. Расте "
            "бавно и обично не боли."
        ),
        "treatment_overview": (
            "Бидејќи е бенигна, обично не е потребен третман. Ако лезијата се "
            "иритира, чеша или пациентот сака отстранување од естетски причини, "
            "дерматолог може да ја отстрани со криотерапија, кир(е)тажа или ласер."
        ),
    },
    {
        "key": "nevus",
        "name": "Nevus (Mole)",
        "severity": Severity.LOW,
        "category": ConditionCategory.BENIGN,
        "description": "Обична бенигна младеж/крт. Следи промени во големина, боја или облик.",
        "symptoms": (
            "Мала, рамномерно обоена дамка (кафеава, црна или телесна боја), со "
            "јасно дефиниран раб и стабилен изглед со текот на времето. Обична "
            "младеж не боли и не крвави."
        ),
        "treatment_overview": (
            "Обичните младежи не бараат третман. Отстранување се разгледува само "
            "ако младежот покаже промени (асиметрија, неправилен раб, промена на "
            "боја/големина) или по лична преференција - секогаш по проценка на "
            "дерматолог."
        ),
    },
    {
        "key": "dermatofibroma",
        "name": "Dermatofibroma",
        "severity": Severity.LOW,
        "category": ConditionCategory.BENIGN,
        "description": "Доброќудна фиброзна кожна брадавица, обично безопасна.",
        "symptoms": (
            "Мал, цврст чвор (обично на нозете), розева, кафеава или црвеникава "
            "боја. Карактеристично се повлекува навнатре кога ќе се притисне од "
            "страните („dimple sign”). Може благо да чеша, но обично не боли."
        ),
        "treatment_overview": (
            "Најчесто не бара третман. Хируршко отстранување се разгледува само ако "
            "лезијата пречи, чеша постојано или пациентот сака да ја отстрани - по "
            "проценка на дерматолог."
        ),
    },
    {
        "key": "vascular_lesion",
        "name": "Vascular Lesion",
        "severity": Severity.LOW,
        "category": ConditionCategory.BENIGN,
        "description": "Доброќудна промена поврзана со крвни садови во кожата.",
        "symptoms": (
            "Црвена или темноцрвена/виолетова дамка предизвикана од крвни садови во "
            "кожата, рамна или благо издигната. Кај некои типови бојата бледнее "
            "привремено при притисок."
        ),
        "treatment_overview": (
            "Најчесто не е потребен третман. Ако лезијата пречи функционално или "
            "естетски, дерматолог може да препорача ласер терапија; пристапот "
            "зависи од типот и длабочината на садовите."
        ),
    },
]


# Hand-written English text for the same 8 conditions, so English never
# depends on a Gemini translation (quota, errors, missing key). Same
# educational, non-prescriptive tone as the Macedonian text above.
CONDITIONS_EN = {
    "melanoma": {
        "description_en": (
            "A malignant lesion of the skin's pigment cells. It needs an urgent "
            "evaluation by a dermatologist."
        ),
        "symptoms_en": (
            "A mole or spot that is asymmetrical, has irregular or blurred "
            "borders, has several colors in the same lesion (brown, black, pink, "
            "blue), is larger than 6 mm, and/or changes in size, shape or color "
            "over time. It may itch, bleed or not heal."
        ),
        "treatment_overview_en": (
            "Dermatologists most often remove the lesion surgically (excision), "
            "sometimes with a check of the nearest lymph nodes. In more advanced "
            "cases, treatment may include immunotherapy or targeted therapy. The "
            "exact approach depends on depth and stage and is decided by a "
            "dermatologist or oncologist after a biopsy."
        ),
    },
    "basal_cell_carcinoma": {
        "description_en": (
            "The most common type of skin cancer. It grows slowly, but it needs "
            "a medical diagnosis and treatment."
        ),
        "symptoms_en": (
            "A shiny or waxy raised bump, a flat scar-like patch that is brown "
            "or flesh-colored, or a sore that bleeds, crusts, heals and then "
            "returns. It is most common on sun-exposed areas (face, ears, neck)."
        ),
        "treatment_overview_en": (
            "It is usually treated with surgical removal (including Mohs surgery, "
            "which carefully preserves healthy tissue). Smaller lesions are "
            "sometimes treated with cryotherapy, topical therapy or radiotherapy. "
            "The choice is made by a dermatologist based on size and location."
        ),
    },
    "squamous_cell_carcinoma": {
        "description_en": (
            "A malignant lesion of the skin's squamous cells. It needs a medical "
            "evaluation."
        ),
        "symptoms_en": (
            "A firm reddish bump, a flat lesion with a scaly or crusted surface, "
            "or a sore or ulcer that does not heal for months. It can also look "
            "like a wart. It is most common on sun-exposed areas."
        ),
        "treatment_overview_en": (
            "The most common approach is surgical removal (excision or Mohs "
            "surgery); for larger or hard-to-reach lesions radiotherapy may be "
            "recommended. The final decision is made by a dermatologist or "
            "oncologist after assessing the stage."
        ),
    },
    "actinic_keratosis": {
        "description_en": (
            "A precancerous change caused by long-term sun exposure."
        ),
        "symptoms_en": (
            "A rough, dry, scaly patch (usually under 2 cm), pink, reddish or "
            "brown, on sun-exposed skin (face, scalp, hands). It may itch or "
            "sting, and is sometimes easier to feel than to see."
        ),
        "treatment_overview_en": (
            "Dermatologists commonly use cryotherapy (freezing), topical therapy "
            "or photodynamic therapy, depending on the number and location of the "
            "lesions. Without treatment, a small percentage can progress to "
            "squamous cell carcinoma, which is why a check-up is recommended."
        ),
    },
    "seborrheic_keratosis": {
        "description_en": (
            "A benign, wart-like skin growth, common in older adults."
        ),
        "symptoms_en": (
            "A waxy, \"stuck-on\" spot with a sharp edge, brown, black or beige, "
            "round or oval, with a slightly rough or warty surface. It grows "
            "slowly and usually does not hurt."
        ),
        "treatment_overview_en": (
            "Because it is benign, treatment is usually not needed. If the lesion "
            "becomes irritated or itchy, or you want it removed for cosmetic "
            "reasons, a dermatologist can remove it with cryotherapy, curettage "
            "or laser."
        ),
    },
    "nevus": {
        "description_en": (
            "An ordinary benign mole. Watch for changes in size, color or shape."
        ),
        "symptoms_en": (
            "A small, evenly colored spot (brown, black or flesh-colored) with a "
            "clearly defined border and a stable appearance over time. An "
            "ordinary mole does not hurt or bleed."
        ),
        "treatment_overview_en": (
            "Ordinary moles do not need treatment. Removal is considered only if "
            "the mole shows changes (asymmetry, irregular border, change in "
            "color or size) or by personal preference, always after a "
            "dermatologist's assessment."
        ),
    },
    "dermatofibroma": {
        "description_en": (
            "A benign fibrous skin nodule that is usually harmless."
        ),
        "symptoms_en": (
            "A small, firm bump (usually on the legs), pink, brown or reddish. "
            "It typically dimples inward when pinched from the sides (the "
            "\"dimple sign\"). It may itch slightly but usually does not hurt."
        ),
        "treatment_overview_en": (
            "It usually needs no treatment. Surgical removal is considered only "
            "if the lesion is bothersome, itches constantly or you want it "
            "removed, after a dermatologist's assessment."
        ),
    },
    "vascular_lesion": {
        "description_en": (
            "A benign change related to the blood vessels in the skin."
        ),
        "symptoms_en": (
            "A red or dark red/purple spot caused by blood vessels in the skin, "
            "flat or slightly raised. In some types the color fades briefly "
            "under pressure."
        ),
        "treatment_overview_en": (
            "Treatment is usually not needed. If the lesion causes functional or "
            "cosmetic concerns, a dermatologist may suggest laser therapy; the "
            "approach depends on the type and depth of the vessels."
        ),
    },
}


class Command(BaseCommand):
    help = (
        "Seeds the 8 SkinCondition records matching the training notebook, "
        "with both Macedonian and English text."
    )

    def handle(self, *args, **options):
        created_count = 0
        updated_count = 0

        for item in CONDITIONS:
            obj, created = SkinCondition.objects.update_or_create(
                key=item["key"],
                defaults={
                    "name": item["name"],
                    "severity": item["severity"],
                    "category": item["category"],
                    "description": item["description"],
                    "symptoms": item["symptoms"],
                    "treatment_overview": item["treatment_overview"],
                    **CONDITIONS_EN[item["key"]],
                },
            )
            if created:
                created_count += 1
            else:
                updated_count += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"Готово. Нови: {created_count}, ажурирани: {updated_count}."
            )
        )
