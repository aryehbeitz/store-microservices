import {
  AdminConfig,
  CreateOrderRequest,
  CreateOrderResponse,
  PaymentWebhook,
  Product,
  RequestLog,
  ServiceStatus,
} from "@honey-store/shared/types";
import axios from "axios";
import cors from "cors";
import express from "express";
import { createServer } from "http";
import mongoose from "mongoose";
import { Server } from "socket.io";
import { readFileSync } from "fs";
import { join } from "path";

// Load version from package.json
let VERSION = "unknown";
try {
  // Try multiple paths for different environments (local dev vs Docker)
  const possiblePaths = [
    join(__dirname, "../package.json"),           // Local dev: dist/apps/backend/../package.json
    join(__dirname, "../../../apps/backend/package.json"), // Docker: dist/apps/backend/../../../apps/backend/package.json
    join(process.cwd(), "apps/backend/package.json"),      // Docker alternative
  ];

  for (const path of possiblePaths) {
    try {
      const packageJson = JSON.parse(readFileSync(path, "utf-8"));
      VERSION = packageJson.version;
      break;
    } catch (e) {
      // Try next path
    }
  }
} catch (error) {
  console.warn("Could not load version from package.json");
}

const app = express();
const httpServer = createServer(app);

// CORS configuration - restrict origins in production
const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(",")
  : ["http://localhost:4200"];

const io = new Server(httpServer, {
  cors: {
    origin: ALLOWED_ORIGINS,
    methods: ["GET", "POST"],
    credentials: true,
  },
});

// Middleware
app.use(
  cors({
    origin: ALLOWED_ORIGINS,
    credentials: true,
  })
);
app.use(express.json());

// Environment variables
const PORT = process.env.PORT || 3000;
const MONGODB_URI =
  process.env.MONGODB_URI || "mongodb://mongodb:27017/honey-store";
const PAYMENT_SERVICE_URL =
  process.env.PAYMENT_SERVICE_URL || "http://payment-service:3002";
const BACKEND_PUBLIC_URL = process.env.BACKEND_PUBLIC_URL || "";
const SERVICE_LOCATION = process.env.SERVICE_LOCATION || "local";
const CONNECTION_METHOD = process.env.CONNECTION_METHOD || "direct";

// Admin configuration
let adminConfig: AdminConfig = {
  simulatePaymentError: false,
  paymentDelayMs: 15000, // 15 seconds - orders will show as pending until webhook returns
};

// Service status tracking
let serviceStatus: ServiceStatus = {
  name: "backend",
  healthy: true,
  location: SERVICE_LOCATION as "local" | "cloud",
  connectionMethod: CONNECTION_METHOD as any,
  enabled: true,
};

// Request logging
const requestLogs: RequestLog[] = [];

function logRequest(log: RequestLog) {
  requestLogs.push(log);
  if (requestLogs.length > 100) {
    requestLogs.shift();
  }
  io.emit("request-log", log);
}

// MongoDB Schema
const orderSchema = new mongoose.Schema(
  {
    items: [
      {
        product: {
          id: String,
          name: String,
          description: String,
          price: Number,
          category: String,
          imageUrl: String,
          inStock: Boolean,
        },
        quantity: Number,
      },
    ],
    total: Number,
    customerName: String,
    customerEmail: String,
    shippingAddress: String,
    paymentStatus: {
      type: String,
      enum: ["pending", "approved", "rejected", "error"],
      default: "pending",
    },
  },
  { timestamps: true }
);

const OrderModel = mongoose.model("Order", orderSchema);

// Products data (stored in backend for easy testing)
const products: Product[] = [
  {
    id: "1",
    name: "Pure Wildflower Honey",
    description:
      "Raw, unfiltered wildflower honey from local beekeepers. Rich in antioxidants and natural enzymes.",
    price: 24.99,
    category: "honey",
    imageUrl:
      "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDQwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjRkZFRTBEIi8+CjxjaXJjbGUgY3g9IjIwMCIgY3k9IjE1MCIgcj0iODAiIGZpbGw9IiNGRkQ3MDAiLz4KPHN2ZyB4PSIxNjAiIHk9IjEyMCIgd2lkdGg9IjgwIiBoZWlnaHQ9IjYwIiB2aWV3Qm94PSIwIDAgMjQgMjQiIGZpbGw9IiNGRkZGRkYiPgo8cGF0aCBkPSJNMTIgMkM2LjQ4IDIgMiA2LjQ4IDIgMTJzNC40OCAxMCAxMCAxMCAxMC00LjQ4IDEwLTEwUzE3LjUyIDIgMTIgMnptLTEgMTdoLTJ2LTJoMnYyem0wLTQtMmgydjJoLTJ2LTJ6bTAtNGgyVjloLTJ2NnoiLz4KPC9zdmc+Cjx0ZXh0IHg9IjIwMCIgeT0iMjAwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjRkZENzAwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSJib2xkIj5Ib25leTwvdGV4dD4KPC9zdmc+",
    inStock: true,
  },
  {
    id: "2",
    name: "Manuka Honey MGO 400+",
    description:
      "Premium New Zealand Manuka honey with MGO 400+ certification. Known for antibacterial properties.",
    price: 49.99,
    category: "honey",
    imageUrl:
      "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDQwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjRkZGRkZGIi8+CjxjaXJjbGUgY3g9IjIwMCIgY3k9IjE1MCIgcj0iODAiIGZpbGw9IiNGRkQ3MDAiLz4KPHN2ZyB4PSIxNjAiIHk9IjEyMCIgd2lkdGg9IjgwIiBoZWlnaHQ9IjYwIiB2aWV3Qm94PSIwIDAgMjQgMjQiIGZpbGw9IiNGRkZGRkYiPgo8cGF0aCBkPSJNMTIgMkM2LjQ4IDIgMiA2LjQ4IDIgMTJzNC40OCAxMCAxMCAxMCAxMC00LjQ4IDEwLTEwUzE3LjUyIDIgMTIgMnptLTEgMTdoLTJ2LTJoMnYyem0wLTQtMmgydjJoLTJ2LTJ6bTAtNGgyVjloLTJ2NnoiLz4KPC9zdmc+Cjx0ZXh0IHg9IjIwMCIgeT0iMjAwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjRkZENzAwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSJib2xkIj5NYW51a2E8L3RleHQ+Cjwvc3ZnPg==",
    inStock: true,
  },
  {
    id: "3",
    name: "Lavender Honey",
    description:
      "Delicate floral honey harvested from lavender fields. Perfect for tea and desserts.",
    price: 28.99,
    category: "honey",
    imageUrl:
      "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDQwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjRkZGRkZGIi8+CjxjaXJjbGUgY3g9IjIwMCIgY3k9IjE1MCIgcj0iODAiIGZpbGw9IiNGRkQ3MDAiLz4KPHN2ZyB4PSIxNjAiIHk9IjEyMCIgd2lkdGg9IjgwIiBoZWlnaHQ9IjYwIiB2aWV3Qm94PSIwIDAgMjQgMjQiIGZpbGw9IiNGRkZGRkYiPgo8cGF0aCBkPSJNMTIgMkM2LjQ4IDIgMiA2LjQ4IDIgMTJzNC40OCAxMCAxMCAxMCAxMC00LjQ4IDEwLTEwUzE3LjUyIDIgMTIgMnptLTEgMTdoLTJ2LTJoMnYyem0wLTQtMmgydjJoLTJ2LTJ6bTAtNGgyVjloLTJ2NnoiLz4KPC9zdmc+Cjx0ZXh0IHg9IjIwMCIgeT0iMjAwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjRkZENzAwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSJib2xkIj5MYXZlbmRlcjwvdGV4dD4KPC9zdmc+",
    inStock: true,
  },
  {
    id: "4",
    name: "Beekeeping Starter Kit",
    description:
      "Complete starter kit with hive, frames, smoker, and protective gear. Everything you need to start beekeeping.",
    price: 299.99,
    category: "equipment",
    imageUrl:
      "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDQwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjRkZGRkZGIi8+CjxyZWN0IHg9IjE2MCIgeT0iMTAwIiB3aWR0aD0iODAiIGhlaWdodD0iMTAwIiBmaWxsPSIjOEI0NTEzIi8+CjxzdmcgeD0iMTYwIiB5PSIxMDAiIHdpZHRoPSI4MCIgaGVpZ2h0PSIxMDAiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0iI0ZGRkZGRiI+CjxwYXRoIGQ9Ik0xMiAyQzYuNDggMiAyIDYuNDggMiAxMnM0LjQ4IDEwIDEwIDEwIDEwLTQuNDggMTAtMTBTMTcuNTIgMiAxMiAyem0tMSAxN2gtMnYtMmgydjJ6bTAtNGgyVjloLTJ2NnoiLz4KPC9zdmc+Cjx0ZXh0IHg9IjIwMCIgeT0iMjIwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjOEI0NTEzIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSJib2xkIj5LaXQ8L3RleHQ+Cjwvc3ZnPg==",
    inStock: true,
  },
  {
    id: "5",
    name: "Professional Bee Suit",
    description:
      "Full-body protection suit with ventilated hood. Made from durable, breathable cotton.",
    price: 89.99,
    category: "equipment",
    imageUrl:
      "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDQwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjRkZGRkZGIi8+CjxyZWN0IHg9IjE2MCIgeT0iMTAwIiB3aWR0aD0iODAiIGhlaWdodD0iMTAwIiBmaWxsPSIjRkZGRkZGIiBzdHJva2U9IiM4QjQ1MTMiIHN0cm9rZS13aWR0aD0iNCIvPgo8c3ZnIHg9IjE2MCIgeT0iMTAwIiB3aWR0aD0iODAiIGhlaWdodD0iMTAwIiB2aWV3Qm94PSIwIDAgMjQgMjQiIGZpbGw9IiM4QjQ1MTMiPgo8cGF0aCBkPSJNMTIgMkM2LjQ4IDIgMiA2LjQ4IDIgMTJzNC40OCAxMCAxMCAxMCAxMC00LjQ4IDEwLTEwUzE3LjUyIDIgMTIgMnptLTEgMTdoLTJ2LTJoMnYyem0wLTQtMmgydjJoLTJ2LTJ6bTAtNGgyVjloLTJ2NnoiLz4KPC9zdmc+Cjx0ZXh0IHg9IjIwMCIgeT0iMjIwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjOEI0NTEzIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSJib2xkIj5TdWl0PC90ZXh0Pgo8L3N2Zz4=",
    inStock: true,
  },
  {
    id: "6",
    name: "Stainless Steel Smoker",
    description:
      "High-quality bee smoker with heat shield. Essential tool for safe hive inspection.",
    price: 34.99,
    category: "equipment",
    imageUrl:
      "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDQwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjRkZGRkZGIi8+CjxyZWN0IHg9IjE2MCIgeT0iMTIwIiB3aWR0aD0iODAiIGhlaWdodD0iNjAiIGZpbGw9IiNDQ0NDQ0MiLz4KPHN2ZyB4PSIxNjAiIHk9IjEyMCIgd2lkdGg9IjgwIiBoZWlnaHQ9IjYwIiB2aWV3Qm94PSIwIDAgMjQgMjQiIGZpbGw9IiNGRkZGRkYiPgo8cGF0aCBkPSJNMTIgMkM2LjQ4IDIgMiA2LjQ4IDIgMTJzNC40OCAxMCAxMCAxMCAxMC00LjQ4IDEwLTEwUzE3LjUyIDIgMTIgMnptLTEgMTdoLTJ2LTJoMnYyem0wLTQtMmgydjJoLTJ2LTJ6bTAtNGgyVjloLTJ2NnoiLz4KPC9zdmc+Cjx0ZXh0IHg9IjIwMCIgeT0iMjAwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjQ0NDQ0NDIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSJib2xkIj5TbW9rZXI8L3RleHQ+Cjwvc3ZnPg==",
    inStock: true,
  },
  {
    id: "7",
    name: "Honey Dipper Set",
    description:
      "Handcrafted wooden honey dippers in various sizes. Perfect for serving honey.",
    price: 12.99,
    category: "accessories",
    imageUrl:
      "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDQwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjRkZGRkZGIi8+CjxjaXJjbGUgY3g9IjIwMCIgY3k9IjE1MCIgcj0iNDAiIGZpbGw9IiNENzcxMDAiLz4KPHN2ZyB4PSIxNjAiIHk9IjEyMCIgd2lkdGg9IjgwIiBoZWlnaHQ9IjYwIiB2aWV3Qm94PSIwIDAgMjQgMjQiIGZpbGw9IiNGRkZGRkYiPgo8cGF0aCBkPSJNMTIgMkM2LjQ4IDIgMiA2LjQ4IDIgMTJzNC40OCAxMCAxMCAxMCAxMC00LjQ4IDEwLTEwUzE3LjUyIDIgMTIgMnptLTEgMTdoLTJ2LTJoMnYyem0wLTQtMmgydjJoLTJ2LTJ6bTAtNGgyVjloLTJ2NnoiLz4KPC9zdmc+Cjx0ZXh0IHg9IjIwMCIgeT0iMjAwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjRDc3MTAwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSJib2xkIj5EaXBwZXI8L3RleHQ+Cjwvc3ZnPg==",
    inStock: true,
  },
  {
    id: "8",
    name: "Glass Honey Jar Set (6 pack)",
    description:
      "Premium glass jars with cork lids. Ideal for storing and gifting honey.",
    price: 24.99,
    category: "accessories",
    imageUrl:
      "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDQwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjRkZGRkZGIi8+CjxjaXJjbGUgY3g9IjIwMCIgY3k9IjE1MCIgcj0iNDAiIGZpbGw9IiNGRkZGRkYiIHN0cm9rZT0iI0ZGRDcwMCIgc3Ryb2tlLXdpZHRoPSI0Ii8+CjxzdmcgeD0iMTYwIiB5PSIxMjAiIHdpZHRoPSI4MCIgaGVpZ2h0PSI2MCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSIjRkZENzAwIj4KPHBhdGggZD0iTTEyIDJDNi40OCAyIDIgNi40OCAyIDEyczQuNDggMTAgMTAgMTAgMTAtNC40OCAxMC0xMFMxNy41MiAyIDEyIDJ6bS0xIDE3aC0ydi0yaDJ2MnptMC00aDJWOWgtMnY2em0wLTRoMnYyaC0ydi0yeiIvPgo8L3N2Zz4KPHRleHQgeD0iMjAwIiB5PSIyMDAiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZpbGw9IiNGRkQ3MDAiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxOCIgZm9udC13ZWlnaHQ9ImJvbGQiPkphcnM8L3RleHQ+Cjwvc3ZnPg==",
    inStock: true,
  },
  {
    id: "9",
    name: "Beeswax Candle Making Kit",
    description:
      "Create your own natural beeswax candles. Includes molds, wicks, and pure beeswax.",
    price: 39.99,
    category: "accessories",
    imageUrl:
      "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDQwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjRkZGRkZGIi8+CjxjaXJjbGUgY3g9IjIwMCIgY3k9IjE1MCIgcj0iNDAiIGZpbGw9IiNGRkQ3MDAiLz4KPHN2ZyB4PSIxNjAiIHk9IjEyMCIgd2lkdGg9IjgwIiBoZWlnaHQ9IjYwIiB2aWV3Qm94PSIwIDAgMjQgMjQiIGZpbGw9IiNGRkZGRkYiPgo8cGF0aCBkPSJNMTIgMkM2LjQ4IDIgMiA2LjQ4IDIgMTJzNC40OCAxMCAxMCAxMCAxMC00LjQ4IDEwLTEwUzE3LjUyIDIgMTIgMnptLTEgMTdoLTJ2LTJoMnYyem0wLTQtMmgydjJoLTJ2LTJ6bTAtNGgyVjloLTJ2NnoiLz4KPC9zdmc+Cjx0ZXh0IHg9IjIwMCIgeT0iMjAwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjRkZENzAwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSJib2xkIj5DYW5kbGU8L3RleHQ+Cjwvc3ZnPg==",
    inStock: true,
  },
];

// Connect to MongoDB
mongoose
  .connect(MONGODB_URI)
  .then(() => {
    console.log("Connected to MongoDB");
    serviceStatus.healthy = true;
    io.emit("service-status", serviceStatus);
  })
  .catch((err) => {
    console.error("MongoDB connection error:", err);
    serviceStatus.healthy = false;
    io.emit("service-status", serviceStatus);
  });

// Socket.io connection
io.on("connection", (socket) => {
  console.log("Admin client connected");

  // Send current status
  socket.emit("service-status", serviceStatus);
  socket.emit("admin-config", adminConfig);
  socket.emit("request-logs", requestLogs);

  // Handle admin config updates
  socket.on("update-admin-config", (config: AdminConfig) => {
    adminConfig = { ...adminConfig, ...config };
    io.emit("admin-config", adminConfig);
  });

  socket.on("disconnect", () => {
    console.log("Admin client disconnected");
  });
});

// Health check
app.get("/health", (req, res) => {
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: "external",
    destination: "backend",
    method: "GET",
    path: "/health",
    status: 200,
  };
  logRequest(log);

  res.json({
    status: "healthy",
    service: "backend",
    version: VERSION,
    mongodb:
      mongoose.connection.readyState === 1 ? "connected" : "disconnected",
    location: SERVICE_LOCATION,
    connectionMethod: CONNECTION_METHOD,
  });
});

// Get products
app.get("/api/products", (req, res) => {
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: "frontend",
    destination: "backend",
    method: "GET",
    path: "/api/products",
  };

  const startTime = Date.now();

  try {
    const category = req.query.category as string | undefined;
    let filteredProducts = products;

    if (category && category !== "all") {
      filteredProducts = products.filter((p) => p.category === category);
    }

    const duration = Date.now() - startTime;
    log.status = 200;
    log.duration = duration;
    logRequest(log);

    res.json(filteredProducts);
  } catch (error) {
    const duration = Date.now() - startTime;
    log.status = 500;
    log.duration = duration;
    logRequest(log);

    console.error("Failed to get products:", error);
    res.status(500).json({ error: "Failed to get products" });
  }
});

// Get single product by ID
app.get("/api/products/:id", (req, res) => {
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: "frontend",
    destination: "backend",
    method: "GET",
    path: `/api/products/${req.params.id}`,
  };

  const startTime = Date.now();

  try {
    const product = products.find((p) => p.id === req.params.id);

    const duration = Date.now() - startTime;
    log.status = product ? 200 : 404;
    log.duration = duration;
    logRequest(log);

    if (product) {
      res.json(product);
    } else {
      res.status(404).json({ error: "Product not found" });
    }
  } catch (error) {
    const duration = Date.now() - startTime;
    log.status = 500;
    log.duration = duration;
    logRequest(log);

    console.error("Failed to get product:", error);
    res.status(500).json({ error: "Failed to get product" });
  }
});

// Get connection method info
app.get("/api/connection-info", (req, res) => {
  const webhookUrl = BACKEND_PUBLIC_URL
    ? `${BACKEND_PUBLIC_URL}/api/webhook/payment`
    : `${req.protocol}://${req.get("host")}/api/webhook/payment`;

  res.json({
    connectionMethod: CONNECTION_METHOD,
    serviceLocation: SERVICE_LOCATION,
    canReceiveWebhooks: true,
    webhookUrl: webhookUrl,
  });
});

// Get all orders
app.get("/api/orders", async (req, res) => {
  const startTime = Date.now();
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: "frontend",
    destination: "backend",
    method: "GET",
    path: "/api/orders",
  };

  try {
    const orders = await OrderModel.find().sort({ createdAt: -1 });
    const duration = Date.now() - startTime;

    log.status = 200;
    log.duration = duration;
    logRequest(log);

    // Add connection method info to response
    const webhookUrl = BACKEND_PUBLIC_URL
      ? `${BACKEND_PUBLIC_URL}/api/webhook/payment`
      : "http://backend:3000/api/webhook/payment";

    res.json({
      orders,
      connectionInfo: {
        method: CONNECTION_METHOD,
        location: SERVICE_LOCATION,
        canReceiveWebhooks: true,
        webhookUrl: webhookUrl,
      },
    });
  } catch (error) {
    const duration = Date.now() - startTime;
    log.status = 500;
    log.duration = duration;
    logRequest(log);

    res.status(500).json({ error: "Failed to fetch orders" });
  }
});

// Get order by ID
app.get("/api/orders/:id", async (req, res) => {
  const startTime = Date.now();
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: "frontend",
    destination: "backend",
    method: "GET",
    path: `/api/orders/${req.params.id}`,
  };

  try {
    const order = await OrderModel.findById(req.params.id);
    const duration = Date.now() - startTime;

    if (!order) {
      log.status = 404;
      log.duration = duration;
      logRequest(log);
      return res.status(404).json({ error: "Order not found" });
    }

    log.status = 200;
    log.duration = duration;
    logRequest(log);

    res.json(order);
  } catch (error) {
    const duration = Date.now() - startTime;
    log.status = 500;
    log.duration = duration;
    logRequest(log);

    res.status(500).json({ error: "Failed to fetch order" });
  }
});

// Create order
app.post("/api/orders", async (req, res) => {
  const startTime = Date.now();
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: "frontend",
    destination: "backend",
    method: "POST",
    path: "/api/orders",
  };

  try {
    const orderData: CreateOrderRequest = req.body;

    // Create order in database
    const order = new OrderModel({
      items: orderData.items,
      total: orderData.total,
      customerName: orderData.customerName,
      customerEmail: orderData.customerEmail,
      shippingAddress: orderData.shippingAddress,
      paymentStatus: "pending",
    });

    await order.save();

    const duration = Date.now() - startTime;
    log.status = 201;
    log.duration = duration;
    logRequest(log);

    // Send payment request to payment service (async)
    processPayment(
      order._id.toString(),
      orderData.total,
      orderData.customerEmail
    );

    const response: CreateOrderResponse = {
      orderId: order._id.toString(),
      message: "Order created successfully. Payment is being processed.",
    };

    res.status(201).json(response);
  } catch (error) {
    const duration = Date.now() - startTime;
    log.status = 500;
    log.duration = duration;
    logRequest(log);

    console.error("Failed to create order:", error);
    res.status(500).json({ error: "Failed to create order" });
  }
});

// Process payment (async function)
async function processPayment(
  orderId: string,
  amount: number,
  customerEmail: string
) {
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: "backend",
    destination: "payment-service",
    method: "POST",
    path: "/payment",
  };

  const startTime = Date.now();

  try {
    // Construct webhook URL
    // If BACKEND_PUBLIC_URL is set, use it (for external access)
    // Otherwise, use internal service name (for cluster-internal access)
    const webhookUrl = BACKEND_PUBLIC_URL
      ? `${BACKEND_PUBLIC_URL}/api/webhook/payment`
      : "http://backend:3000/api/webhook/payment";

    // Convert payment delay from ms to seconds
    const sleepSeconds = Math.max(
      1,
      Math.floor((adminConfig.paymentDelayMs || 2000) / 1000)
    );

    // Prepare payment request matching external service API
    const paymentRequest = {
      webhook_url: webhookUrl,
      sleep: sleepSeconds,
      data: {
        orderId: orderId,
        amount: amount,
        currency: "USD",
        customerEmail: customerEmail,
      },
    };

    const response = await axios.post(
      `${PAYMENT_SERVICE_URL}/api/payment`,
      paymentRequest,
      {
        headers: {
          "Content-Type": "application/json",
        },
      }
    );

    const duration = Date.now() - startTime;
    log.status = response.status;
    log.duration = duration;
    logRequest(log);

    console.log("Payment request sent:", response.data);

    // Store mapping of payment_id to orderId for webhook lookup
    if (response.data && response.data.id) {
      // In-memory mapping - could be enhanced with Redis or database
      // This assumes webhook comes back with orderId in data field
    }
  } catch (error) {
    const duration = Date.now() - startTime;
    log.status = 500;
    log.duration = duration;
    logRequest(log);

    console.error("Failed to send payment request:", error);

    // Update order status to error
    await OrderModel.findByIdAndUpdate(orderId, { paymentStatus: "error" });
  }
}

// Payment webhook
app.post("/api/webhook/payment", async (req, res) => {
  const startTime = Date.now();
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: "payment-service",
    destination: "backend",
    method: "POST",
    path: "/api/webhook/payment",
  };

  try {
    const webhookPayload = req.body;

    // Support two webhook formats:
    // 1. Internal payment service: { orderId, paymentId, status, message }
    // 2. External service: { payment_id, timestamp, data: { orderId } }
    let orderId: string;
    let paymentId: string;
    let status: string;
    let message: string;

    if (webhookPayload.orderId) {
      // Internal payment service format
      orderId = webhookPayload.orderId;
      paymentId = webhookPayload.paymentId;
      status = webhookPayload.status || 'approved';
      message = webhookPayload.message || 'Payment processed';
    } else if (webhookPayload.data?.orderId) {
      // External service format
      orderId = webhookPayload.data.orderId;
      paymentId = webhookPayload.payment_id;
      status = 'approved';
      message = 'Payment approved successfully';
    } else {
      throw new Error("Missing orderId in webhook data");
    }

    // Update order payment status
    const paymentStatus = status === 'approved' ? 'approved' : 'rejected';
    const updatedOrder = await OrderModel.findByIdAndUpdate(
      orderId,
      { paymentStatus },
      { new: true }
    );

    const duration = Date.now() - startTime;
    log.status = 200;
    log.duration = duration;
    logRequest(log);

    console.log("Payment webhook received:", {
      orderId,
      paymentId,
      status,
      message,
    });

    // Create webhook response matching our internal format for frontend
    const webhookResponse: PaymentWebhook = {
      orderId,
      paymentId,
      status: status as 'approved' | 'rejected',
      message,
    };

    // Emit real-time updates to connected clients
    if (updatedOrder) {
      io.emit("order-updated", updatedOrder);
      io.emit("payment-webhook", webhookResponse);
    }

    res.json({ message: "Webhook processed successfully" });
  } catch (error) {
    const duration = Date.now() - startTime;
    log.status = 500;
    log.duration = duration;
    logRequest(log);

    console.error("Failed to process webhook:", error);
    res.status(500).json({ error: "Failed to process webhook" });
  }
});

// Retry payment for an order
app.post("/api/orders/:id/retry-payment", async (req, res) => {
  const startTime = Date.now();
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: "frontend",
    destination: "backend",
    method: "POST",
    path: `/api/orders/${req.params.id}/retry-payment`,
  };

  try {
    const order = await OrderModel.findById(req.params.id);
    const duration = Date.now() - startTime;

    if (!order) {
      log.status = 404;
      log.duration = duration;
      logRequest(log);
      return res.status(404).json({ error: "Order not found" });
    }

    // Only allow retry for orders with error or rejected payment status
    if (order.paymentStatus !== "error" && order.paymentStatus !== "rejected") {
      log.status = 400;
      log.duration = duration;
      logRequest(log);
      return res.status(400).json({
        error:
          "Order payment cannot be retried. Current status: " +
          order.paymentStatus,
      });
    }

    // Reset payment status to pending
    order.paymentStatus = "pending";
    await order.save();

    // Retry payment processing
    processPayment(order._id.toString(), order.total, order.customerEmail);

    log.status = 200;
    log.duration = duration;
    logRequest(log);

    res.json({
      message: "Payment retry initiated successfully",
      orderId: order._id.toString(),
      status: "pending",
    });
  } catch (error) {
    const duration = Date.now() - startTime;
    log.status = 500;
    log.duration = duration;
    logRequest(log);

    res.status(500).json({ error: "Failed to retry payment" });
  }
});

// Clear all orders
app.delete("/api/orders", async (req, res) => {
  const startTime = Date.now();
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: "frontend",
    destination: "backend",
    method: "DELETE",
    path: "/api/orders",
  };

  try {
    const result = await OrderModel.deleteMany({});
    const duration = Date.now() - startTime;

    log.status = 200;
    log.duration = duration;
    logRequest(log);

    res.json({
      message: "All orders cleared successfully",
      deletedCount: result.deletedCount,
    });
  } catch (error) {
    const duration = Date.now() - startTime;
    log.status = 500;
    log.duration = duration;
    logRequest(log);

    res.status(500).json({ error: "Failed to clear orders" });
  }
});

// Get versions from all services
app.get("/api/services/versions", async (req, res) => {
  const versions: { [key: string]: string } = {};

  // Backend version
  versions.backend = VERSION;

  // Try to get frontend version from version.json
  try {
    // Frontend serves a version.json file created during build
    // Try both LoadBalancer IP (from env) and internal service name
    const frontendUrls = [];

    // If we have a FRONTEND_URL env var, use that
    if (process.env.FRONTEND_URL) {
      frontendUrls.push(`${process.env.FRONTEND_URL}/assets/version.json`);
    }

    // Also try internal service name
    frontendUrls.push('http://frontend/assets/version.json');

    for (const url of frontendUrls) {
      try {
        const frontendResponse = await axios.get(url, { timeout: 2000 });
        if (frontendResponse.data && frontendResponse.data.version) {
          versions.frontend = frontendResponse.data.version;
          break;
        }
      } catch (e) {
        // Try next URL
      }
    }

    if (!versions.frontend) {
      versions.frontend = "N/A";
    }
  } catch (error) {
    versions.frontend = "N/A";
  }

  // Try to get payment service version
  try {
    const paymentHealthUrl = `${PAYMENT_SERVICE_URL}/health`;
    const paymentResponse = await axios.get(paymentHealthUrl, { timeout: 2000 });
    versions["payment-service"] = paymentResponse.data.version || "N/A";
  } catch (error) {
    versions["payment-service"] = "N/A";
  }

  // Try to get MongoDB version
  try {
    if (mongoose.connection.readyState === 1) {
      const adminDb = mongoose.connection.db.admin();
      const serverInfo = await adminDb.serverInfo();
      versions.mongodb = serverInfo.version;
    } else {
      versions.mongodb = "disconnected";
    }
  } catch (error) {
    versions.mongodb = "error";
  }

  res.json(versions);
});

// Version endpoint - returns current backend version
app.get("/api/version", (req, res) => {
  const packageJson = require("../package.json");
  res.json({
    service: "backend",
    version: packageJson.version,
    timestamp: new Date().toISOString(),
    serviceLocation: SERVICE_LOCATION,
    connectionMethod: CONNECTION_METHOD,
  });
});

// Version update endpoint for watch script
app.post("/api/version-update", (req, res) => {
  const { service, version } = req.body;

  console.log(`Version update received: ${service} → ${version}`);

  // Emit version update event to all connected clients
  io.emit("version-update", { service, version });

  res.json({ message: "Version update broadcasted" });
});

// Start server
httpServer.listen(PORT, () => {
  console.log(`Backend service listening on port ${PORT}`);
  console.log(`MongoDB URI: ${MONGODB_URI}`);
  console.log(`Payment Service URL: ${PAYMENT_SERVICE_URL}`);
  if (BACKEND_PUBLIC_URL) {
    console.log(`Backend Public URL: ${BACKEND_PUBLIC_URL}`);
  }
  console.log(`Service Location: ${SERVICE_LOCATION}`);
  console.log(`Connection Method: ${CONNECTION_METHOD}`);
  console.log(`🔥 BACKEND RUNNING LOCALLY: Code changes are instant!`);

  // Add a test endpoint to verify local backend
  app.get("/api/test-local", (req, res) => {
    res.json({
      running: "LOCAL",
      message: "This backend is running locally on your machine",
      timestamp: new Date().toISOString(),
      serviceLocation: SERVICE_LOCATION,
      connectionMethod: CONNECTION_METHOD,
      pid: process.pid,
      nodeVersion: process.version,
    });
  });
});
