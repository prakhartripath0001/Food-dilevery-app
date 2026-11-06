const db = require("../config/database");

async function createOrder(req, res, next) {
  const connection = await db.getConnection();
  try {
    const { user_id, restaurant_id, delivery_address_id, payment_method, items } = req.body;

    if (!user_id || !restaurant_id || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({
        status: "FAIL",
        message: "user_id, restaurant_id, and at least one item are required"
      });
    }

    await connection.beginTransaction();

    // 1. Validate items and calculate total amount
    let totalAmount = 0;
    const itemDetails = [];

    for (const item of items) {
      const [rows] = await connection.query(
        "SELECT id, price, is_available FROM menu_items WHERE id = ? AND restaurant_id = ?",
        [item.menu_item_id, restaurant_id]
      );

      if (rows.length === 0) {
        await connection.rollback();
        return res.status(404).json({
          status: "FAIL",
          message: `Menu item #${item.menu_item_id} not found in this restaurant`
        });
      }

      if (!rows[0].is_available) {
        await connection.rollback();
        return res.status(400).json({
          status: "FAIL",
          message: `Menu item #${item.menu_item_id} is currently unavailable`
        });
      }

      const unitPrice = parseFloat(rows[0].price);
      const qty = parseInt(item.quantity, 10) || 1;
      totalAmount += unitPrice * qty;

      itemDetails.push({
        menu_item_id: item.menu_item_id,
        quantity: qty,
        unit_price: unitPrice
      });
    }

    // 2. Insert into orders table
    const [orderResult] = await connection.query(
      `INSERT INTO orders (user_id, restaurant_id, delivery_address_id, total_amount, payment_method, status, payment_status)
       VALUES (?, ?, ?, ?, ?, 'placed', 'pending')`,
      [user_id, restaurant_id, delivery_address_id || null, totalAmount, payment_method || "cod"]
    );

    const orderId = orderResult.insertId;

    // 3. Insert items into order_items table
    for (const detail of itemDetails) {
      await connection.query(
        `INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price)
         VALUES (?, ?, ?, ?)`,
        [orderId, detail.menu_item_id, detail.quantity, detail.unit_price]
      );
    }

    await connection.commit();

    res.status(201).json({
      status: "SUCCESS",
      message: "Order placed successfully",
      data: {
        order_id: orderId,
        total_amount: totalAmount,
        status: "placed"
      }
    });
  } catch (error) {
    await connection.rollback();
    next(error);
  } finally {
    connection.release();
  }
}

async function getOrderById(req, res, next) {
  try {
    const { id } = req.params;

    const [orders] = await db.query(
      `SELECT o.*, r.name AS restaurant_name
       FROM orders o
       JOIN restaurants r ON o.restaurant_id = r.id
       WHERE o.id = ?`,
      [id]
    );

    if (orders.length === 0) {
      return res.status(404).json({
        status: "FAIL",
        message: "Order not found"
      });
    }

    const [items] = await db.query(
      `SELECT oi.*, m.name, m.image_url
       FROM order_items oi
       JOIN menu_items m ON oi.menu_item_id = m.id
       WHERE oi.order_id = ?`,
      [id]
    );

    res.json({
      status: "SUCCESS",
      data: {
        ...orders[0],
        items
      }
    });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  createOrder,
  getOrderById
};
