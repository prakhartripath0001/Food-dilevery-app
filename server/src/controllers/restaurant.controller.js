const db = require("../config/database");

async function getAllRestaurants(req, res, next) {
  try {
    const { search } = req.query;
    let query = "SELECT id, name, description, image_url, address, phone, rating, is_open FROM restaurants WHERE 1=1";
    const params = [];

    if (search) {
      query += " AND (name LIKE ? OR description LIKE ?)";
      params.push(`%${search}%`, `%${search}%`);
    }

    query += " ORDER BY rating DESC";

    const [restaurants] = await db.query(query, params);
    res.json({
      status: "SUCCESS",
      count: restaurants.length,
      data: restaurants
    });
  } catch (error) {
    next(error);
  }
}

async function getRestaurantById(req, res, next) {
  try {
    const { id } = req.params;
    const [restaurants] = await db.query(
      "SELECT id, name, description, image_url, address, phone, rating, is_open FROM restaurants WHERE id = ?",
      [id]
    );

    if (restaurants.length === 0) {
      return res.status(404).json({
        status: "FAIL",
        message: "Restaurant not found"
      });
    }

    const restaurant = restaurants[0];

    // Fetch menu items for this restaurant
    const [menuItems] = await db.query(
      `SELECT m.id, m.name, m.description, m.price, m.image_url, m.is_available,
              c.name AS category_name, c.id AS category_id
       FROM menu_items m
       LEFT JOIN categories c ON m.category_id = c.id
       WHERE m.restaurant_id = ?`,
      [id]
    );

    res.json({
      status: "SUCCESS",
      data: {
        ...restaurant,
        menu: menuItems
      }
    });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getAllRestaurants,
  getRestaurantById
};
