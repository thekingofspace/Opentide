--!strict
const Catalog = require(script.Parent.Parent)

const Clothes: Catalog.Clothes = {
    RobloxJacket = { Name = "Roblox Jacket", Kind = "Shirt", Asset = 607785314, Order = 1 },
    SimplePattern = { Name = "Simple Pattern", Kind = "Shirt", Asset = 3670737444, Order = 2 },
    GreenJersey = { Name = "Green Jersey", Kind = "Shirt", Asset = 382538059, Order = 3 },
    BluePlaid = { Name = "Blue Plaid", Kind = "Shirt", Asset = 398635081, Order = 4 },
    PizzaShirt = { Name = "Pizza Shirt", Kind = "Shirt", Asset = 4047884939, Order = 5 },
    GuitarTee = { Name = "Guitar Tee", Kind = "Shirt", Asset = 4047884046, Order = 6 },

    BlackJeans = { Name = "Black Jeans", Kind = "Pants", Asset = 382537569, Order = 1 },
    DarkGreenJeans = { Name = "Dark Green Jeans", Kind = "Pants", Asset = 144076760, Order = 2 },
    SkaterPants = { Name = "Skater Pants", Kind = "Pants", Asset = 398635338, Order = 3 },
    JeanShorts = { Name = "Jean Shorts", Kind = "Pants", Asset = 382537806, Order = 4 },
    BlackJeansSneakers = { Name = "Jeans and Sneakers", Kind = "Pants", Asset = 382538503, Order = 5 },
}

return Clothes
