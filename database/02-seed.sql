-- =============================================
-- Food Delivery App - Seed Data
-- =============================================

USE food_delivery_db;

-- Seed Categories
INSERT IGNORE INTO categories (id, name, image_url) VALUES
(1, 'Pizza', 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400'),
(2, 'Burgers', 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400'),
(3, 'Indian', 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400'),
(4, 'Desserts', 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=400');

-- Seed Sample Restaurants
INSERT IGNORE INTO restaurants (id, name, description, image_url, address, phone, rating, is_open) VALUES
(1, 'Pizza Palace', 'Authentic stone-baked Italian pizzas & pastas', 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600', '123 Main Street', '+1234567890', 4.8, TRUE),
(2, 'Burger Barn', 'Gourmet smashed burgers, fries and shakes', 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600', '456 Market Avenue', '+1234567891', 4.6, TRUE);

-- Seed Sample Menu Items
INSERT IGNORE INTO menu_items (restaurant_id, category_id, name, description, price, image_url, is_available) VALUES
(1, 1, 'Margherita Pizza', 'Classic tomato sauce, fresh mozzarella, and basil', 12.99, 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=400', TRUE),
(1, 1, 'Pepperoni Feast', 'Double pepperoni with extra mozzarella cheese', 15.49, 'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=400', TRUE),
(2, 2, 'Classic Cheeseburger', 'Angus beef patty, cheddar, lettuce, tomato & special sauce', 9.99, 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400', TRUE),
(2, 2, 'Truffle Fries', 'Crispy fries tossed with truffle oil and parmesan', 5.99, 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=400', TRUE);
