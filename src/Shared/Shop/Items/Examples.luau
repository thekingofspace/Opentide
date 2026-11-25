--!strict
const Shop = require(script.Parent.Parent)

const Items: Shop.Items = {
    MorePropsSmall = {
        Name = "25 more props",
        Description = "place 25 more props at once",
        Product = 0,
        Props = 25,
        Order = 1,
        Preview = { 6 },
    },
    MorePropsBig = {
        Name = "100 more props",
        Description = "place 100 more props at once",
        Product = 0,
        Props = 100,
        Order = 2,
        Preview = { 7 },
    },
    KitchenPack = {
        Name = "Kitchen pack",
        Description = "unlocks every kitchen prop",
        Product = 0,
        Pack = "Kitchen",
        Order = 3,
        Preview = { 26, 24, 25 },
    },
    RustyNailsPack = {
        Name = "Rusty nails",
        Description = "unlocks rusty nails for the baseball bat",
        Product = 0,
        Pack = "RustyNails",
        Order = 5,
    },
    CampingPack = {
        Name = "Camping pack",
        Description = "unlocks every camping prop",
        Product = 0,
        Pack = "Camping",
        Order = 4,
        Preview = { 9, 10, 11, 8 },
    },
}

return Items
