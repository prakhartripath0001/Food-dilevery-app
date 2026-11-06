const express = require("express");
const router = express.Router();
const restaurantController = require("../controllers/restaurant.controller");

router.get("/", restaurantController.getAllRestaurants);
router.get("/:id", restaurantController.getRestaurantById);

module.exports = router;
