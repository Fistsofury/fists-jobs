Config = {}

Config.Stations = {
    ["Valentine"] = {x = -174.06, y = 626.62, z = 114.03},
    ["Rhodes"] = {x = 1228.24, y = -1300.25, z = 76.91},
    ["Annesburg"] = {x = 2941.71, y = 1287.29, z = 44.64},
    ["Saint Denis"] = {x = 2626.64, y = -1492.2, z = 45.97},
    ["Emerald"] = {x = 1525.17, y = 442.78, z = 90.68},
    ["Flatneck"] = {x = -331.62, y = -355.67, z = 88.04},
    ["Blackwater"] = {x = -880.79, y = -1333.61, z = 43.97},
    ["Riggs"] = {x = -1096.52, y = -571.95, z = 82.4},
    ["Wallace"] = {x = -1308.62, y = 395.28, z = 95.38},
    ["Bacchus"] = {x = 579.76, y = 1687.35, z = 187.67},
    ["Van Horn"] = {x = 2893.26, y = 626.43, z = 57.73},
    ["MacFarlane's Ranch"] = {x = -2499.23, y = -2423.44, z = 60.6},
    ["Armadillo"] = {x = -3734.04, y = -2602.07, z = -12.92},
    ["Benedict Point"] = {x = -5230.58, y = -3470.41, z = -20.57}
}

Config.TownHashes = {
    ["Annesburg"] = { coords = vector3(0, 0, 0), hash = 7359335 },
    ["Armadillo"] = { coords = vector3(-3741.01, -2632.69, -13.94), hash = -744494798 },
    ["BeechersHope"] = { coords = vector3(-1657.38, -1364.63, 84.12), hash = -1708386982 },
    ["Blackwater"] = { coords = vector3(-785.76, -1324.27, 43.88), hash = 1053078005 },
    ["Braithwaite"] = { coords = vector3(1004.79, -1752.91, 46.62), hash = 1778899666 },
    ["Caliga"] = { coords = vector3(1716.24, -1378.73, 43.52), hash = 1862420670 },
    ["Emerald"] = { coords = vector3(1525.17, 442.78, 90.68), hash = -473051294 },
    ["Manzanita"] = { coords = vector3(-1934.79, -2194.87, 66.87), hash = 1463094051 },
    ["Rhodes"] = { coords = vector3(1233.61, -1299.71, 76.92), hash = 2046780049 },
    ["StDenis"] = { coords = vector3(2627.83, -1490.29, 45.57), hash = -765540529 },
    ["Strawberry"] = { coords = vector3(-1764.89, -379.43, 156.84), hash = 427683330 },
    ["Tumbleweed"] = { coords = vector3(-5515.68, -2926.48, -1.94), hash = -1524959147 },
    ["Valentine"] = { coords = vector3(-179.94, 626.62, 114.03), hash = 459833523 },
    ["VanHorn"] = { coords = vector3(2983.78, 563.64, 46.88), hash = 2126321341 },
    ["Wallace"] = { coords = vector3(-1308.62, 395.28, 95.38), hash = -872622034 },
    ["Wapiti"] = { coords = vector3(618.15, 2202.02, 238.12), hash = 1663398575 }
}

Config.Webhooks = {
    medical = "",
    conductor = ""
}

Config.Jobs = {
    easttrain = {
        onDutyCommand = "dutyon", 
        offDutyCommand = "dutyoff", 
        salary = {
            jobGrade2 = 100,
            jobGrade3 = 100
        },
        salaryTime = 30 -- Time in minutes to be paid while on duty
    }
    --Dont add more jobs, it wont do anything
}
