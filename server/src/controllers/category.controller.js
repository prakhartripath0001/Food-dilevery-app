const db = require("../config/database");

async function getAllCategories(req, res, next) {
  try {
    const [categories] = await db.query(
      "SELECT id, name, image_url FROM categories ORDER BY name ASC"
    );
    res.json({
      status: "SUCCESS",
      data: categories
    });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getAllCategories
};
