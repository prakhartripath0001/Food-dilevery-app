const db = require("../config/database");

const addressSelect = `
  SELECT id, address_type AS addressType, recipient_name AS recipientName,
         phone, address_line1 AS addressLine, address_line2 AS addressLine2,
         landmark, city, state, postal_code AS pincode,
         latitude, longitude, is_default AS isDefault, created_at AS createdAt
  FROM addresses`;

function fail(res, status, message) {
  return res.status(status).json({ success: false, message });
}

function readAddress(body) {
  body = body && typeof body === "object" && !Array.isArray(body) ? body : {};
  const address = {
    addressType: typeof body.addressType === "string" ? body.addressType.trim().toUpperCase() : "HOME",
    recipientName: typeof body.recipientName === "string" ? body.recipientName.trim() : "",
    phone: typeof body.phone === "string" ? body.phone.trim() : "",
    addressLine: typeof body.addressLine === "string" ? body.addressLine.trim() : "",
    addressLine2: typeof body.addressLine2 === "string" ? body.addressLine2.trim() : "",
    landmark: typeof body.landmark === "string" ? body.landmark.trim() : "",
    city: typeof body.city === "string" ? body.city.trim() : "",
    state: typeof body.state === "string" ? body.state.trim() : "",
    pincode: typeof body.pincode === "string" ? body.pincode.trim() : "",
    latitude: body.latitude === undefined || body.latitude === null || body.latitude === "" ? null : Number(body.latitude),
    longitude: body.longitude === undefined || body.longitude === null || body.longitude === "" ? null : Number(body.longitude)
  };

  const errors = [];
  if (!["HOME", "WORK", "OTHER"].includes(address.addressType)) {
    errors.push("addressType must be HOME, WORK, or OTHER");
  }
  if (!address.recipientName || address.recipientName.length > 100) {
    errors.push("recipientName is required and must be at most 100 characters");
  }
  if (!/^[+0-9().\-\s]{6,20}$/.test(address.phone)) {
    errors.push("phone must contain 6 to 20 valid phone characters");
  }
  if (!address.addressLine || address.addressLine.length > 255) {
    errors.push("addressLine is required and must be at most 255 characters");
  }
  if (address.addressLine2.length > 255 || address.landmark.length > 255) {
    errors.push("addressLine2 and landmark must be at most 255 characters");
  }
  if (!address.city || address.city.length > 100 || address.state.length > 100) {
    errors.push("city is required and city/state must be at most 100 characters");
  }
  if (address.pincode.length > 10) {
    errors.push("pincode must be at most 10 characters");
  }

  const hasLatitude = address.latitude !== null;
  const hasLongitude = address.longitude !== null;
  if (hasLatitude !== hasLongitude) {
    errors.push("latitude and longitude must be provided together");
  } else if (hasLatitude &&
      (!Number.isFinite(address.latitude) || address.latitude < -90 || address.latitude > 90 ||
       !Number.isFinite(address.longitude) || address.longitude < -180 || address.longitude > 180)) {
    errors.push("latitude or longitude is outside its valid range");
  }

  return { address, errors };
}

function addressValues(address) {
  return [
    address.addressType,
    address.recipientName,
    address.phone,
    address.addressLine,
    address.addressLine2 || null,
    address.landmark || null,
    address.city,
    address.state || null,
    address.pincode || null,
    address.latitude,
    address.longitude
  ];
}

async function getAddresses(req, res, next) {
  try {
    const [addresses] = await db.query(
      `${addressSelect} WHERE user_id = ? ORDER BY is_default DESC, created_at DESC, id DESC`,
      [req.user.id]
    );
    return res.json({ success: true, data: addresses });
  } catch (error) {
    return next(error);
  }
}

async function getAddressById(req, res, next) {
  const addressId = Number(req.params.id);
  if (!Number.isSafeInteger(addressId) || addressId < 1) {
    return fail(res, 400, "Address id must be a positive integer");
  }

  try {
    const [addresses] = await db.query(
      `${addressSelect} WHERE id = ? AND user_id = ?`,
      [addressId, req.user.id]
    );
    if (addresses.length === 0) return fail(res, 404, "Address not found");
    return res.json({ success: true, data: addresses[0] });
  } catch (error) {
    return next(error);
  }
}

async function createAddress(req, res, next) {
  const { address, errors } = readAddress(req.body);
  if (errors.length > 0) return fail(res, 400, errors.join("; "));

  let connection;
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();
    await connection.query("SELECT id FROM users WHERE id = ? FOR UPDATE", [req.user.id]);
    const [defaults] = await connection.query(
      "SELECT id FROM addresses WHERE user_id = ? AND is_default = TRUE LIMIT 1",
      [req.user.id]
    );
    const isDefault = defaults.length === 0;
    const [result] = await connection.query(
      `INSERT INTO addresses
         (user_id, address_type, recipient_name, phone, address_line1, address_line2,
          landmark, city, state, postal_code, latitude, longitude, is_default)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [req.user.id, ...addressValues(address), isDefault]
    );
    const [savedAddresses] = await connection.query(
      `${addressSelect} WHERE id = ? AND user_id = ?`,
      [result.insertId, req.user.id]
    );
    await connection.commit();
    return res.status(201).json({
      success: true,
      message: "Address saved successfully",
      data: savedAddresses[0]
    });
  } catch (error) {
    if (connection) await connection.rollback();
    return next(error);
  } finally {
    if (connection) connection.release();
  }
}

async function updateAddress(req, res, next) {
  const addressId = Number(req.params.id);
  if (!Number.isSafeInteger(addressId) || addressId < 1) {
    return fail(res, 400, "Address id must be a positive integer");
  }
  const { address, errors } = readAddress(req.body);
  if (errors.length > 0) return fail(res, 400, errors.join("; "));

  try {
    const [existingAddresses] = await db.query(
      "SELECT id FROM addresses WHERE id = ? AND user_id = ?",
      [addressId, req.user.id]
    );
    if (existingAddresses.length === 0) return fail(res, 404, "Address not found");

    await db.query(
      `UPDATE addresses
       SET address_type = ?, recipient_name = ?, phone = ?, address_line1 = ?,
           address_line2 = ?, landmark = ?, city = ?, state = ?, postal_code = ?,
           latitude = ?, longitude = ?
       WHERE id = ? AND user_id = ?`,
      [...addressValues(address), addressId, req.user.id]
    );
    const [addresses] = await db.query(
      `${addressSelect} WHERE id = ? AND user_id = ?`,
      [addressId, req.user.id]
    );
    if (addresses.length === 0) return fail(res, 404, "Address not found");
    return res.json({
      success: true,
      message: "Address updated successfully",
      data: addresses[0]
    });
  } catch (error) {
    return next(error);
  }
}

async function deleteAddress(req, res, next) {
  const addressId = Number(req.params.id);
  if (!Number.isSafeInteger(addressId) || addressId < 1) {
    return fail(res, 400, "Address id must be a positive integer");
  }

  let connection;
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();
    await connection.query("SELECT id FROM users WHERE id = ? FOR UPDATE", [req.user.id]);
    const [addresses] = await connection.query(
      "SELECT id, is_default FROM addresses WHERE id = ? AND user_id = ? FOR UPDATE",
      [addressId, req.user.id]
    );
    if (addresses.length === 0) {
      await connection.rollback();
      return fail(res, 404, "Address not found");
    }

    await connection.query("DELETE FROM addresses WHERE id = ? AND user_id = ?", [addressId, req.user.id]);
    if (addresses[0].is_default) {
      await connection.query(
        `UPDATE addresses SET is_default = TRUE
         WHERE user_id = ? ORDER BY created_at DESC, id DESC LIMIT 1`,
        [req.user.id]
      );
    }
    await connection.commit();
    return res.json({ success: true, message: "Address deleted successfully" });
  } catch (error) {
    if (connection) await connection.rollback();
    return next(error);
  } finally {
    if (connection) connection.release();
  }
}

async function setDefaultAddress(req, res, next) {
  const addressId = Number(req.params.id);
  if (!Number.isSafeInteger(addressId) || addressId < 1) {
    return fail(res, 400, "Address id must be a positive integer");
  }

  let connection;
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();
    await connection.query("SELECT id FROM users WHERE id = ? FOR UPDATE", [req.user.id]);
    const [addresses] = await connection.query(
      "SELECT id FROM addresses WHERE id = ? AND user_id = ? FOR UPDATE",
      [addressId, req.user.id]
    );
    if (addresses.length === 0) {
      await connection.rollback();
      return fail(res, 404, "Address not found");
    }

    await connection.query("UPDATE addresses SET is_default = FALSE WHERE user_id = ?", [req.user.id]);
    await connection.query(
      "UPDATE addresses SET is_default = TRUE WHERE id = ? AND user_id = ?",
      [addressId, req.user.id]
    );
    const [savedAddresses] = await connection.query(
      `${addressSelect} WHERE id = ? AND user_id = ?`,
      [addressId, req.user.id]
    );
    await connection.commit();
    return res.json({
      success: true,
      message: "Default address updated successfully",
      data: savedAddresses[0]
    });
  } catch (error) {
    if (connection) await connection.rollback();
    return next(error);
  } finally {
    if (connection) connection.release();
  }
}

module.exports = {
  getAddresses,
  getAddressById,
  createAddress,
  updateAddress,
  deleteAddress,
  setDefaultAddress
};
