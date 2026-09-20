import Foundation

extension Catalog {
    /// English cooking steps, paired with the Chinese ones in `Catalog.recipes`.
    ///
    /// These are translations of the same method, not a different recipe: the same
    /// time blocks, the same temperatures, the same warnings. A recipe missing from
    /// this table simply shows its Chinese steps, whatever the language preference.
    private static let stepsPart1: [String: [String]] = [
        "sesame": [
            "0–5 min: start the quick-cooking rice with the water the packet calls for. Cut the chicken into 2cm pieces and the broccoli into florets. Keep raw and ready-to-eat boards separate.",
            "5–20 min: heat oil in a large frying pan and brown the chicken in two batches; at the same time steam the broccoli for 6–8 minutes in a second pan.",
            "20–30 min: once the chicken reaches 74°C / 165°F at the centre, stir in the soy sauce and sesame seeds with a splash of water to make a glaze. Serve with the rice and broccoli."
        ],
        "curry": [
            "0–6 min: start the quick-cooking rice. Cut the chicken, potatoes and carrots into 1cm pieces.",
            "6–12 min: heat oil in a large pan, stir-fry the chicken, then add the vegetables and the chilli-free curry powder.",
            "12–28 min: add the milk and enough water to almost cover, put the lid on and simmer until the potato is tender and the chicken reaches 74°C / 165°F. Season with salt and serve with the rice. Ingredients straight from the freezer need extra time."
        ],
        "beefpasta": [
            "0–7 min: bring a large pan of water to the boil, dice the beef small and wash the spinach. Cook the spaghetti for the time on the packet once the water boils.",
            "7–18 min: in a second pan, brown the beef in hot oil, add the crushed tomatoes and bring to a simmer, then stir in the spinach and salt. Take the beef to at least 63°C / 145°F and rest it for 3 minutes.",
            "18–25 min: drain the pasta, fold it through the sauce with a little pasta water, check the beef is cooked through and serve."
        ],
        "noodles": [
            "0–6 min: bring a large pan of water to the boil, wash the greens and cut the carrot into fine strips. Boil the eggs in a second pan until white and yolk are firm.",
            "6–15 min: cook the carrot in the boiling water first, then the wheat noodles for the time on the packet, adding the bok choy at the end until tender.",
            "15–20 min: season the broth with soy sauce and oil. Peel and halve the eggs into the bowls. Parents: cut pieces to a size suited to a young child."
        ],
        "salmon": [
            "0–5 min: start the quick-cooking rice. Cut the salmon into 5 portions, checking carefully for bones, and wash and trim the broccoli.",
            "5–20 min: pan-fry the salmon in oil until the centre reaches 63°C / 145°F; steam the broccoli until tender at the same time.",
            "20–25 min: season the fish with salt and lemon juice and serve with the rice and broccoli. Frozen fish must be thawed in the fridge in advance; thawing time is not included here."
        ],
        "tofurice": [
            "0–10 min: cook the quick-cooking rice as the packet says, then spread it out to let the steam escape. Drain and dice the tofu, and dice the carrot small.",
            "10–20 min: scramble the eggs in oil in a large pan until firm and set them aside; then fry the tofu, carrot and peas until cooked.",
            "20–30 min: add the rice, egg and soy sauce in batches and toss until piping hot. This recipe uses freshly cooked rice — it does not depend on day-old rice."
        ],
        "chickenpasta": [
            "0–7 min: bring a large pan of water to the boil, cut the chicken into thin strips and the broccoli into florets.",
            "7–18 min: cook the penne for the time on the packet, adding the broccoli for the last few minutes. In a second pan, fry the chicken in batches until the centre reaches 74°C / 165°F.",
            "18–25 min: drain the pasta and broccoli, combine with the chicken, and toss with salt and a little pasta water."
        ],
        "oats": [
            "Simmer the oats in the milk for about 8 minutes, stirring so they do not catch, and loosen with water if they thicken too much.",
            "Slice the bananas, wash the blueberries and divide between the bowls. For a young child, crush or halve the blueberries according to age."
        ],
        "eggs": [
            "Toast the bread in batches. Peel the oranges and cut them to a size that suits the children.",
            "Beat the eggs and scramble them in an oiled pan until completely set. Serve with the toast and oranges."
        ],
        "yogurt": [
            "Choose oats whose packet says they can be eaten without cooking; if yours must be cooked, cook them first and allow extra time.",
            "Divide the yogurt between bowls and stir through the oats, banana and washed blueberries. Adjust the fruit size to the children's ages."
        ],
        "gingerchicken": [
            "0–6 min: start the quick-cooking rice with the water the packet calls for. Cut the chicken breast into thin strips, shred the ginger, and wash and cut the bok choy.",
            "6–23 min: heat oil in a large frying pan and stir-fry the ginger and chicken; cook the chicken in batches to 74°C / 165°F at the centre, set it aside, then wilt the bok choy in the same pan.",
            "23–30 min: return the chicken, add soy sauce and a splash of water and toss together. Serve over the rice, portioned out. Thaw raw meat in the fridge ahead of time and keep raw and cooked separate."
        ],
        "mushroomchicken": [
            "0–6 min: start the quick-cooking rice. Slice the chicken thinly, slice the mushrooms and cut the broccoli into florets.",
            "6–23 min: fry the chicken in batches to 74°C / 165°F at the centre; steam the broccoli for 6–8 minutes at the same time, and soften the mushrooms in the chicken pan.",
            "23–30 min: add the broccoli, soy sauce and a splash of water and toss. Serve over the rice, portioned out. Thaw raw meat in the fridge ahead of time and keep raw and cooked separate."
        ],
        "pineapplechicken": [
            "0–6 min: start the quick-cooking rice. Cut the chicken and pepper into chunks and drain the pineapple.",
            "6–23 min: stir-fry the chicken in hot oil in batches to 74°C / 165°F at the centre, add the pepper until softened, then the pineapple and soy sauce.",
            "23–30 min: add a little water and toss to a light sauce — no chilli. Serve over the rice, portioned out. Thaw raw meat in the fridge ahead of time and keep raw and cooked separate."
        ],
        "teriyakichicken": [
            "0–6 min: start the quick-cooking rice. Cut the chicken into thin strips and slice the carrots thinly.",
            "6–23 min: fry the chicken in batches to 74°C / 165°F at the centre; steam the carrots at the same time and mix the soy sauce, maple syrup and 50mL water.",
            "23–30 min: pour the sauce into the chicken pan, bring to the boil and coat. Serve with the carrots alongside and the rice, portioned out. Thaw raw meat in the fridge ahead of time and keep raw and cooked separate."
        ],
        "chickenpeas": [
            "0–6 min: start the quick-cooking rice. Cut the chicken into 1cm dice and dice the carrot small.",
            "6–23 min: stir-fry the chicken in hot oil in a large pan; add the carrot, peas and a splash of water, cover and cook until the chicken reaches 74°C / 165°F at the centre.",
            "23–30 min: stir through the soy sauce, making sure the vegetables are tender. Serve over the rice, portioned out. Thaw raw meat in the fridge ahead of time and keep raw and cooked separate."
        ],
        "beefbroccoli": [
            "0–6 min: start the quick-cooking rice. Slice the beef thinly across the grain, cut the broccoli into florets and mince the garlic.",
            "6–23 min: steam the broccoli for 6–8 minutes; in a second large pan, fry the garlic and beef in batches to 63°C / 145°F at the centre.",
            "23–30 min: rest the beef for 3 minutes, then toss it through with the broccoli, soy sauce and a splash of water. Serve over the rice, portioned out. Thaw raw meat in the fridge ahead of time and keep raw and cooked separate."
        ],
        "beefmushroom": [
            "0–6 min: start the quick-cooking rice. Cut the beef into thin strips, slice the mushrooms and wash the spinach.",
            "6–23 min: fry the beef in hot oil in batches to 63°C / 145°F at the centre, set aside and rest for 3 minutes; soften the mushrooms in the same pan, then wilt the spinach.",
            "23–30 min: return the beef, add soy sauce and a splash of water and toss. Serve over the rice, portioned out. Thaw raw meat in the fridge ahead of time and keep raw and cooked separate."
        ],
        "beefcelery": [
            "0–6 min: start the quick-cooking rice. Cut the beef, celery and carrot into fine strips, stringing the celery first.",
            "6–23 min: fry the beef in batches to 63°C / 145°F at the centre, set aside and rest for 3 minutes; stir-fry the carrot and celery with a little water until tender.",
            "23–30 min: return the beef to the pan and toss with the soy sauce. Serve over the rice, portioned out. Thaw raw meat in the fridge ahead of time and keep raw and cooked separate."
        ],
        "beefpepper": [
            "0–6 min: start the quick-cooking rice. Cut the beef into thin strips and deseed and slice the pepper.",
            "6–23 min: fry the beef in hot oil in batches to 63°C / 145°F at the centre, set aside and rest for 3 minutes; soften the pepper in the same pan.",
            "23–30 min: return the beef, add the soy sauce and a little water and toss. Red bell pepper is not hot. Serve over the rice, portioned out. Thaw raw meat in the fridge ahead of time and keep raw and cooked separate."
        ]
    ]

    private static let stepsPart2: [String: [String]] = [
        "porkcabbage": [
            "0–6 min: start the quick-cooking rice. Cut the pork tenderloin into fine strips, shred the cabbage and mince the ginger.",
            "6–23 min: once the oil is hot, stir-fry the ginger and pork in batches to 63°C / 145°F at the centre, set aside and rest for 3 minutes; soften the cabbage in the same pan.",
            "23–30 min: return the pork, add the soy sauce and a splash of water and toss. Serve over the rice, portioned out. Thaw raw meat in the fridge ahead of time and keep raw and cooked separate."
        ],
        "porkmushroom": [
            "0–6 min: start the quick-cooking rice. Slice the pork thinly, slice the mushrooms, and wash and cut the bok choy.",
            "6–23 min: fry the pork in batches to 63°C / 145°F at the centre, set aside and rest for 3 minutes; cook the mushrooms and bok choy until tender.",
            "23–30 min: return the pork and stir through the soy sauce with a little water. Serve over the rice, portioned out. Thaw raw meat in the fridge ahead of time and keep raw and cooked separate."
        ],
        "porkzucchini": [
            "0–6 min: start the quick-cooking rice. Cut the pork into thin strips and slice the zucchini and carrot thinly.",
            "6–23 min: fry the pork in batches to 63°C / 145°F at the centre, set aside and rest for 3 minutes; cook both vegetables through with a little water.",
            "23–30 min: return the tenderloin and toss with the soy sauce. Serve over the rice, portioned out. Thaw raw meat in the fridge ahead of time and keep raw and cooked separate."
        ],
        "shrimpegg": [
            "0–6 min: start the quick-cooking rice. Use thawed prawns and check they are deveined. Beat the eggs and cut the broccoli into florets.",
            "6–23 min: steam the broccoli; scramble the eggs in an oiled pan until set and lift them out, then cook the prawns in batches until the flesh is pearly and opaque.",
            "23–30 min: warm the egg and prawns together with a little salt and set the broccoli alongside. Serve over the rice, portioned out. Thaw raw seafood in the fridge ahead of time and keep raw and cooked separate."
        ],
        "shrimppeas": [
            "0–6 min: start the quick-cooking rice and spread it out to steam off once cooked. Use prawns thawed in advance and dice the carrot small.",
            "6–23 min: scramble the eggs until completely set and lift them out, then cook the prawns until opaque; add the carrot, peas and a splash of water and cook until tender.",
            "23–30 min: fold in the egg, the fresh rice and the soy sauce in two batches and toss until piping hot — no day-old rice needed. Serve portioned out. Thaw raw seafood in the fridge ahead of time and keep raw and cooked separate."
        ],
        "shrimpcorn": [
            "0–6 min: start the quick-cooking rice. Use thawed prawns and dice the zucchini small.",
            "6–23 min: cook the prawns until opaque and lift them out; cook the zucchini and corn in the same pan until tender.",
            "23–30 min: season with salt and warm the prawns back through. Serve over the rice, portioned out. Thaw raw seafood in the fridge ahead of time and keep raw and cooked separate."
        ],
        "codtomato": [
            "0–6 min: start the quick-cooking rice. Check the cod for bones and cut it into large pieces; wash the spinach.",
            "6–23 min: heat oil, add the crushed tomatoes and bring to a simmer, then lay in the cod and poach gently to 63°C / 145°F at the centre; add the spinach until wilted.",
            "23–30 min: season with salt and fold gently so the fish stays in pieces. Serve over the rice, portioned out. Thaw raw fish in the fridge ahead of time and keep raw and cooked separate."
        ],
        "codginger": [
            "0–6 min: start the quick-cooking rice. Check the fish for bones and divide it into thin portions, shred the ginger, and wash and cut the bok choy.",
            "6–23 min: put the fish on a plate, scatter over the ginger and steam to 63°C / 145°F at the centre; in a second pan, cook the bok choy in oil until tender.",
            "23–30 min: spoon soy sauce over the steamed fish and serve the greens alongside, over the rice. Thaw raw fish in the fridge ahead of time and keep raw and cooked separate."
        ],
        "tofutomato": [
            "0–6 min: start the quick-cooking rice. Drain the tofu and cut it into small pieces; beat the eggs.",
            "6–23 min: scramble the eggs in oil until completely set and lift them out; bring the crushed tomatoes to a simmer in the pan and add the tofu to cook gently for 8 minutes.",
            "23–30 min: return the egg, season with salt and warm through — the sauce is good spooned over the rice. Serve portioned out."
        ],
        "tofumushroom": [
            "0–6 min: start the quick-cooking rice. Drain and cube the tofu, slice the mushrooms, and wash and cut the bok choy.",
            "6–23 min: fry the tofu in a large pan in batches until lightly golden on both sides and lift it out; cook the mushrooms and greens, adding a splash of water to finish them.",
            "23–30 min: return the tofu and toss through the soy sauce until hot. Serve over the rice, portioned out."
        ],
        "chickpeacurry": [
            "0–6 min: start the quick-cooking rice. Drain and rinse the chickpeas, slice the carrot thinly and wash the spinach.",
            "6–23 min: cook the carrot with the chilli-free curry powder in oil, add the milk and enough water to soften, then the chickpeas and simmer until hot through.",
            "23–30 min: add the spinach until wilted and season with salt. Serve over the rice, portioned out."
        ],
        "chickenudon": [
            "0–7 min: bring a large pan of water to the boil, cut the chicken into thin strips and shred the cabbage and carrot.",
            "7–20 min: cook the udon as the packet says, loosening the strands, and drain; in a second pan fry the chicken in batches to 74°C / 165°F at the centre, then cook the vegetables until tender.",
            "20–25 min: add the udon, soy sauce and a little cooking water and toss in batches. Divide into portions for everyone at the table."
        ],
        "chickenvermicelli": [
            "0–7 min: bring a large pan of water to the boil, shred the chicken finely and wash and cut the greens; soak the rice vermicelli for as long as the packet says.",
            "7–20 min: simmer the chicken and carrot until the chicken reaches 74°C / 165°F at the centre, then add the vermicelli and cook as the packet directs.",
            "20–25 min: add the bok choy until tender and season with soy sauce and oil, adding water to get the broth you want. Divide into portions for everyone at the table."
        ],
        "chickensoba": [
            "0–7 min: bring a large pan of water to the boil, cut the chicken into thin strips and the broccoli into florets.",
            "7–20 min: cook the soba as the packet says and steam the broccoli separately; in a second pan fry the chicken in batches to 74°C / 165°F at the centre.",
            "20–25 min: drain the noodles, add the chicken and broccoli, and toss with soy sauce, sesame seeds and a little cooking water. Divide into portions for everyone at the table."
        ],
        "chickenorzo": [
            "0–7 min: bring a large pan of water to the boil and dice the chicken and zucchini small.",
            "7–20 min: cook the orzo as the packet says; in a second pan stir-fry the chicken to 74°C / 165°F at the centre, then add the zucchini and crushed tomatoes and cook through.",
            "20–25 min: drain the orzo, fold it into the sauce and season with salt and a little cooking water. Divide into portions for everyone at the table."
        ],
        "beefudon": [
            "0–7 min: bring a large pan of water to the boil, slice the beef thinly across the grain, and wash and cut the mushrooms and cabbage.",
            "7–20 min: simmer the mushrooms and beef in water until the beef reaches 63°C / 145°F at the centre; hold at a gentle simmer for 3 minutes, then add the udon.",
            "20–25 min: cook the cabbage until tender, season with soy sauce and oil, and check the noodles are heated through as the packet directs. Divide into portions for everyone at the table."
        ],
        "beefcabbagenoodles": [
            "0–7 min: bring a large pan of water to the boil, cut the beef into fine strips and shred the cabbage.",
            "7–20 min: cook the wheat noodles as the packet says and drain; in a second pan cook the beef to 63°C / 145°F at the centre, lift it out to rest for 3 minutes, then soften the cabbage.",
            "20–25 min: return the beef with the noodles and toss in batches with soy sauce and a splash of water. Divide into portions for everyone at the table."
        ],
        "porknoodles": [
            "0–7 min: bring a large pan of water to the boil, cut the tenderloin and carrot into fine strips and wash the spinach.",
            "7–20 min: once boiling, cook the carrot and pork — the pork to at least 63°C / 145°F, then 3 minutes more at a gentle simmer — and add the noodles to cook through.",
            "20–25 min: add the spinach until tender, season with soy sauce and oil, and top up with hot water to taste. Divide into portions for everyone at the table."
        ],
        "porktomatopasta": [
            "0–7 min: bring a large pan of water to the boil, dice the tenderloin small and slice the zucchini thinly.",
            "7–20 min: cook the penne as the packet says; in a second pan fry the pork in hot oil, add the tomatoes and zucchini and simmer gently, taking the pork to 63°C / 145°F and holding it 3 minutes more.",
            "20–25 min: drain the pasta, fold it through the sauce and season with salt. Divide into portions for everyone at the table."
        ],
        "shrimpudon": [
            "0–7 min: bring a large pan of water to the boil, use prawns thawed in advance, cut the broccoli into florets and the carrot into fine strips.",
            "7–20 min: cook the udon as the packet says, loosening the strands; steam the vegetables until tender; in a large pan cook the prawns until the flesh is pearly and opaque.",
            "20–25 min: add the udon, vegetables, soy sauce and a little cooking water and toss in batches. Divide into portions for everyone at the table."
        ],
        "shrimpspaghetti": [
            "0–7 min: bring a large pan of water to the boil, use thawed prawns, wash the spinach and mince the garlic.",
            "7–20 min: cook the spaghetti as the packet says; in a second pan cook the garlic and prawns in oil until the prawns are opaque, then wilt the spinach.",
            "20–25 min: drain the pasta into the pan and toss with lemon juice, salt and a little cooking water. Divide into portions for everyone at the table."
        ],
        "shrimpvermicelli": [
            "0–7 min: bring a large pan of water to the boil, thaw the prawns in advance and soak the rice vermicelli as the packet says; beat the eggs and cut the cabbage into lengths.",
            "7–20 min: once boiling, cook the prawns until opaque and add the vermicelli to cook through; pour in the beaten egg slowly to make egg ribbons and cook until completely set.",
            "20–25 min: add the cabbage until tender and season with soy sauce and oil. Divide into portions for everyone at the table."
        ],
        "tunapasta": [
            "0–7 min: bring a large pan of water to the boil, drain the canned light tuna and flake it with a fork.",
            "7–20 min: cook the pasta as the packet says; in a second pan simmer the oil, crushed tomatoes and peas until the peas are tender, then fold in the tuna to warm through.",
            "20–25 min: drain the pasta, toss it through the sauce and season lightly with salt. Divide into portions for everyone at the table."
        ],
        "salmonpasta": [
            "0–7 min: bring a large pan of water to the boil, bone the salmon and cut it into small pieces, and cut the broccoli into florets.",
            "7–20 min: cook the penne as the packet says, adding the broccoli for the last few minutes; in a second pan fry the salmon in oil to 63°C / 145°F at the centre, then add the milk and simmer gently.",
            "20–25 min: drain the pasta and broccoli into the fish pan, fold gently into a light creamy sauce and season with salt. Divide into portions for everyone at the table."
        ],
        "tofusoba": [
            "0–7 min: bring a large pan of water to the boil, drain and cube the tofu, cut the carrot into fine strips and wash the spinach.",
            "7–20 min: cook the soba as the packet says; fry the tofu in batches until lightly golden, add the carrot with a splash of water to cook through, then wilt the spinach.",
            "20–25 min: drain the noodles and fold them in with soy sauce, sesame seeds and a little cooking water. Divide into portions for everyone at the table."
        ],
        "mushroomtofunoodles": [
            "0–7 min: bring a large pan of water to the boil, cube the tofu, slice the mushrooms, and wash and cut the cabbage.",
            "7–20 min: fry the mushrooms in oil, add plenty of water and bring to the boil, add the tofu and simmer gently for 5 minutes, then cook the wheat noodles in it as the packet says.",
            "20–25 min: add the cabbage until tender and season with soy sauce. Divide into portions for everyone at the table."
        ],
        "eggtomatonoodles": [
            "0–7 min: bring a large pan of water to the boil, beat the eggs and wash the spinach.",
            "7–20 min: scramble the eggs in oil until completely set and lift them out; add the crushed tomatoes and water, bring to the boil and cook the noodles in it as the packet says.",
            "20–25 min: return the egg, add the spinach until tender and season with salt. Divide into portions for everyone at the table."
        ],
        "chickpeapasta": [
            "0–7 min: bring a large pan of water to the boil, drain and rinse the canned chickpeas and dice the zucchini small.",
            "7–20 min: cook the penne as the packet says; in a second pan cook the zucchini in hot oil, then add the crushed tomatoes and chickpeas and simmer until tender and hot through.",
            "20–25 min: drain the pasta, fold it through the sauce and season with salt. Divide into portions for everyone at the table."
        ],
        "turkeytacos": [
            "0–8 min: drain and rinse the black beans; dice the tomatoes small and shred the lettuce finely, keeping the tools for raw meat and salad separate.",
            "8–23 min: brown the ground turkey in hot oil, breaking it up, to 74°C / 165°F at the centre, then add the beans, salt and a splash of water to heat through; warm the tortillas in batches in a second dry pan.",
            "23–30 min: fill the soft tortillas with the meat and beans, lettuce and tomato — about two each. No hot sauce."
        ]
    ]

    private static let stepsPart3: [String: [String]] = [
        "chickenwraps": [
            "0–8 min: cut the chicken breast into thin strips; wash and cut the cucumber and lettuce into strips, keeping raw-meat tools separate.",
            "8–23 min: fry the chicken strips in hot oil in batches to 74°C / 165°F at the centre and season with salt; warm the tortillas as the packet says.",
            "23–30 min: spread plain yogurt on each tortilla, add the chicken, cucumber and lettuce, roll up tightly and cut in half."
        ],
        "beanquesadillas": [
            "0–7 min: drain the black beans and mash them roughly; dice the pepper small.",
            "7–15 min: cook the pepper and corn in a little oil until tender, then stir in the beans to heat through.",
            "15–30 min: put the beans and grated cheddar on one half of each tortilla and fold over; cook in batches in two pans at once until golden on both sides and the cheese has melted, then cut into wedges. One pan takes longer."
        ],
        "chickpeapita": [
            "0–6 min: drain and rinse the chickpeas; wash and dice the cucumber and tomato small.",
            "6–14 min: warm the chickpeas with a little water and crush them lightly; mix the yogurt with lemon juice and salt. Warm the pitas as the packet says.",
            "14–20 min: cut each pita into two pockets and fill with the chickpeas, vegetables and yogurt sauce."
        ],
        "chickencouscous": [
            "0–6 min: boil the water; cut the chicken into thin strips and dice the carrot small. Cover the couscous with boiling water as the packet says and leave it to stand.",
            "6–20 min: stir-fry the chicken in a large pan to 74°C / 165°F at the centre, then add the carrot, peas and a splash of water and cook covered until tender.",
            "20–25 min: fluff the couscous with a fork and fold through the chicken, vegetables and salt."
        ],
        "lentilcouscous": [
            "0–5 min: drain and rinse the lentils; cover the couscous with boiling water as the packet says and leave it to stand, and wash the spinach.",
            "5–15 min: simmer the crushed tomatoes and cooked lentils in oil until hot through, then add the spinach until wilted.",
            "15–20 min: season with salt and spoon over the fluffed couscous."
        ],
        "appleoats": [
            "0–5 min: wash and core the apples and dice them small; peel them for a young child.",
            "5–15 min: simmer the oats, milk and apple together for about 10 minutes, stirring often and loosening with water if they thicken. Add the cinnamon, check the apple is soft and divide between bowls."
        ],
        "pumpkinoats": [
            "0–3 min: stir the oats, milk and plain pumpkin purée together in a pan.",
            "3–12 min: simmer until the oats are soft, stirring often and loosening with water if needed; slice the bananas and add them to the bowls."
        ],
        "strawberryoats": [
            "0–10 min: simmer the oats in the milk until soft, loosening with water if they thicken; meanwhile wash, hull and slice the strawberries.",
            "10–15 min: divide the oats between bowls, let them cool a little and stir through the plain yogurt and strawberries. No overnight preparation needed."
        ],
        "pearyogurt": [
            "Choose oats whose packet says they can be eaten without cooking; otherwise cook them first and allow extra time.",
            "Wash, core and dice the pears; divide the plain yogurt between bowls and add the oats and pear. For a young child, soften the pear according to age."
        ],
        "peachyogurt": [
            "Choose oats that can be eaten without cooking; if yours must be cooked, do that first and allow extra time.",
            "Wash, stone and slice the peaches, cutting them small enough for your children, and divide between bowls with the plain yogurt and oats."
        ],
        "berryfrenchtoast": [
            "0–5 min: beat the eggs with the milk and wash the blueberries; dip each slice of wholemeal bread briefly on both sides.",
            "5–23 min: oil two pans and cook the toast in batches side by side, about 3 minutes a side, until the egg is completely set at 71°C / 160°F in the middle. One pan takes longer.",
            "23–25 min: plate up with the blueberries, halved or crushed for a young child."
        ],
        "bananapancakes": [
            "0–7 min: blitz the oats fine, mash the bananas and mix with the eggs and milk; wash and cut the strawberries.",
            "7–27 min: oil two pans and cook 8cm pancakes in batches, about 3 minutes a side, until cooked through at 71°C / 160°F in the middle. One pan takes longer.",
            "27–30 min: serve with the plain yogurt and strawberries, divided by appetite."
        ],
        "spinachomelet": [
            "0–6 min: wash and cut the spinach and beat the eggs; peel and segment the oranges and toast the bread in batches.",
            "6–17 min: wilt the spinach in oil, then pour in the egg — in two pans or two batches — and cook thin omelettes until completely set at 71°C / 160°F in the middle.",
            "17–20 min: cut the omelettes into pieces and serve with the toast and oranges."
        ],
        "avocadoeggtoast": [
            "0–6 min: toast the bread in batches, peel, stone and mash the avocado, and wash and cut the tomatoes.",
            "6–16 min: beat the eggs and scramble them in an oiled pan in batches until completely set.",
            "16–20 min: spread the avocado on the toast, pile on the egg and serve the tomato alongside."
        ],
        "peanutbananatoast": [
            "0–6 min: toast the bread in batches and slice the bananas thinly; make sure everyone at the table can eat peanuts and milk.",
            "6–10 min: spread the toast thinly with smooth peanut butter, lay the banana on top and pour the milk. Young children should not be given a spoonful of peanut butter on its own."
        ],
        "cottagefruittoast": [
            "0–6 min: toast the bread in batches and wash, hull and cut the strawberries.",
            "6–10 min: spread the toast with cottage cheese and serve with the strawberries. Refrigerate the remaining cheese promptly."
        ],
        "breakfastburrito": [
            "0–6 min: drain and rinse the black beans, wash and cut the spinach and beat the eggs.",
            "6–20 min: cook the spinach and beans in oil until hot through and lift them out; scramble the eggs until completely set. Warm the tortillas in a second pan.",
            "20–25 min: fill the tortillas with the beans, greens and egg, roll tightly and cut into pieces a child can hold."
        ],
        "breakfastquesadilla": [
            "0–5 min: wash and dice the tomatoes small and beat the eggs.",
            "5–13 min: cook the tomato in oil until slightly reduced, pour in the egg and cook until completely set.",
            "13–25 min: put the egg and cheddar on one half of each tortilla and fold over; cook in batches in two pans at once until the cheese melts, then cut into wedges."
        ],
        "corneggporridge": [
            "0–5 min: start the quick-cooking rice in about 2 litres of water and beat the eggs. This uses quick-cooking rice — it is not a long-simmered congee from raw grain.",
            "5–20 min: add the corn and cook until the grains are soft, topping up with water as needed; add the milk and bring gently back to heat.",
            "20–25 min: pour in the beaten egg slowly to make ribbons, cook until completely set, season with salt and let it cool a little before serving."
        ],
        "savorytofuoats": [
            "0–5 min: dice the tofu small, wash and cut the spinach and beat the eggs.",
            "5–16 min: cook the oats in about 1.5 litres of water until soft, then add the tofu, spinach and oil and heat through, loosening with water if it thickens.",
            "16–20 min: stir in the egg and cook until completely set, season with soy sauce and divide between bowls."
        ],
        "breakfasttomatonoodles": [
            "0–5 min: boil the water, beat the eggs and wash the spinach.",
            "5–15 min: scramble the eggs in oil until completely set, add the crushed tomatoes and hot water and bring to the boil; cook the noodles in it as the packet says.",
            "15–20 min: add the spinach until tender, season with salt and divide, broth and all, into breakfast bowls."
        ],
        "eggmuffin": [
            "0–6 min: split the English muffins and toast them in batches, wash and cut the spinach and beat the eggs.",
            "6–16 min: wilt the spinach in oil, add the egg and cook until completely set.",
            "16–20 min: sandwich the egg, greens and cheddar inside the muffins and close them while hot."
        ],
        "hunanpork": [
            "0–7 min: start the quick-cooking rice; slice the tenderloin thinly, slice the green and bell peppers, crush the garlic, and wash and cut the bok choy. This is the everyday tenderloin version.",
            "7–20 min: cook the green and bell peppers in a little oil until the skins blister and lift them out; add more oil and cook the pork in batches until done, then return the peppers with the garlic and soy sauce. Cook the bok choy plainly in a second pan.",
            "20–30 min: make sure the pork has reached 63°C at the centre and hold or rest it for 3 minutes; serve with the rice and greens. Chilli varieties differ in heat — use fewer and make up the volume with bell pepper."
        ],
        "hunanbeef": [
            "0–7 min: start the quick-cooking rice; slice the beef thinly across the grain, string and cut the celery, ring the green chillies, mince the ginger and garlic, and slice the carrot thinly.",
            "7–22 min: steam the carrot in a second pan; fry the beef in batches in a large hot pan to 63°C at the centre, then lift it out to rest for 3 minutes. Cook the ginger, garlic, chilli and celery in the same pan until done.",
            "22–30 min: return the beef, toss quickly with the soy sauce and serve with the rice and steamed carrot. Add more chilli if you like it hotter — do not serve this pan to someone who does not eat chilli."
        ],
        "hunanchilifish": [
            "0–7 min: start the quick-cooking rice and bring the steamer to the boil; cut the thawed, boned fish fillet into 2cm-thick pieces and top with ginger, garlic and chopped salted chilli. Fillet is used here instead of fish head, which is easier at home.",
            "7–23 min: steam the fish for 10–15 minutes once the water boils — longer for thicker pieces — until it reaches 63°C at the centre; cook the bok choy in oil in a second pan. The chopped chilli is already salty, so add no more salt.",
            "23–30 min: scatter spring onion over the fish and serve with the rice and greens. If someone does not eat chilli, steam a separate plate with ginger and spring onion so no chilli sauce reaches it, and adjust what you buy to the version you actually cook."
        ],
        "sichuanmapo": [
            "0–7 min: start the quick-cooking rice; cube the tofu, mince the spring onion and garlic, wash the bok choy and slake the cornstarch in a little cold water.",
            "7–22 min: cook the ground pork in oil, breaking it up, to 71°C at the centre, then add the garlic and chilli bean paste over a low heat until fragrant; add about 350mL water, slide in the tofu and simmer gently for 8 minutes, nudging rather than stirring. Cook the cabbage in a second pan.",
            "22–30 min: add the cornstarch water a little at a time until the sauce just thickens, then scatter over the ground Sichuan pepper and spring onion; serve with the rice and greens. The bean paste is already salty. Both the pepper and the paste can be reduced, but the paste still carries heat."
        ],
        "sichuankungpao": [
            "0–8 min: start the quick-cooking rice; dice the chicken small, dice the cucumber and carrot, chop the spring onion and garlic, and mix the soy sauce, vinegar, sugar and cornstarch with 80mL water.",
            "8–22 min: soften the carrot with a little water and set aside. Fry the chicken in batches in a large hot pan to 74°C at the centre and lift it out; over a low heat cook the dried chillies and garlic without letting them burn, then return the chicken and vegetables.",
            "22–30 min: pour in the stirred sauce and cook until it thickens, then add the ground Sichuan pepper, spring onion and roasted peanuts and serve with the rice. This is the everyday version with added vegetables; whole dried chillies can be picked out, but the sauce is still hot. Contains peanuts."
        ],
        "sichuanyuxiang": [
            "0–8 min: start the quick-cooking rice; cut the tenderloin, carrot, pepper and mushrooms into fine strips. Mix the soy sauce, vinegar, sugar and cornstarch with 100mL water. \"Yu-xiang\" is the name of the seasoning — this recipe contains no fish.",
            "8–22 min: fry the pork strips in batches in a large hot pan to 63°C at the centre, lift out and rest for 3 minutes; over a low heat cook the ginger, garlic and chilli bean paste, then add the vegetable strips with a splash of water until tender.",
            "22–30 min: return the pork, stir the sauce again and pour it in, tossing until it coats everything evenly, and serve with the rice. This is the everyday version using mushrooms in place of wood-ear; the bean paste can be reduced."
        ]
    ]

    /// All English steps. Split into parts purely so the compiler can type-check
    /// them quickly; callers see one table.
    public static let stepsEN: [String: [String]] =
        stepsPart1.merging(stepsPart2) { first, _ in first }
                  .merging(stepsPart3) { first, _ in first }
}

extension Recipe {
    /// This recipe's English steps, whether it is built in or one the family added.
    public var englishSteps: [String]? { stepsEnglish ?? Catalog.stepsEN[id] }

    /// The steps to show, as (Chinese, English) pairs. A missing translation never
    /// hides the method: whichever language exists is shown.
    public func steps(in language: RecipeLanguage) -> [(zh: String?, en: String?)] {
        let english = englishSteps
        let wantsZh = language.showsChinese || english == nil
        let wantsEn = language.showsEnglish && english != nil
        let count = max(steps.count, english?.count ?? 0)
        return (0..<count).map { index in
            (zh: wantsZh && index < steps.count ? steps[index] : nil,
             en: wantsEn && index < (english?.count ?? 0) ? english?[index] : nil)
        }.filter { $0.zh != nil || $0.en != nil }
    }
    /// The dish name, written the way this family reads recipes.
    public func title(in language: RecipeLanguage) -> String {
        switch language {
        case .both: return name
        case .chinese: return zh
        case .english: return en
        }
    }
}
