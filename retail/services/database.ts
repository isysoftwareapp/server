/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { SiteContent } from "../types";

// Use centralized API
const API_BASE = import.meta.env.VITE_API_URL || "http://localhost:8080";
const RETAIL_API_PATH = "/retail/v1";

export const fetchSiteContent = async (): Promise<SiteContent | null> => {
  console.log("🚀 fetchSiteContent called");
  try {
    const url = `${API_BASE}${RETAIL_API_PATH}/metadata`;
    console.log("📡 Making GET request to:", url);
    const response = await fetch(url);
    console.log("📡 Response status:", response.status);
    console.log("📡 Response ok:", response.ok);

    if (!response.ok) {
      console.error("❌ Response not ok, status:", response.status);
      const errorText = await response.text();
      console.error("❌ Response error text:", errorText);
      throw new Error("Failed to fetch content");
    }

    const data = await response.json();
    console.log("✅ Fetch successful, data:", data);

    // Centralized API returns { success: true, data: {...} }
    if (data.success && data.data) {
      return data.data.content || data.data;
    }

    return data.content || data;
  } catch (error) {
    console.error("💥 Error fetching site content:", error);
    return null;
  }
};

export const saveSiteContent = async (
  content: SiteContent
): Promise<boolean> => {
  console.log("🚀 saveSiteContent called with content:", content);
  try {
    const token = localStorage.getItem("admin_token");
    console.log("🔑 Token from localStorage:", token ? "present" : "missing");

    if (!token) {
      console.error("❌ No authentication token found");
      return false;
    }

    const url = `${API_BASE}${RETAIL_API_PATH}/metadata`;
    console.log("📡 Making POST request to:", url);
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ content }),
    });

    console.log("📡 Response status:", response.status);
    console.log("📡 Response ok:", response.ok);

    if (!response.ok) {
      console.error("❌ Response not ok, status:", response.status);
      const errorText = await response.text();
      console.error("❌ Response error text:", errorText);
      throw new Error("Failed to save content");
    }

    const data = await response.json();
    console.log("✅ Save successful, response:", data);
    return data.success !== false;
  } catch (error) {
    console.error("💥 Error saving site content:", error);
    return false;
  }
};

export const authenticateAdmin = async (
  username: string,
  password: string
): Promise<{ success: boolean; token?: string }> => {
  console.log("🚀 authenticateAdmin called with username:", username);
  try {
    // TODO: Implement authentication endpoint in centralized API
    // For now, use a simple check (replace with real API call)
    console.log("⚠️  Using local authentication (temporary)");

    // Temporary: Simple check for admin/admin
    if (username === "admin" && password === "admin") {
      const tempToken = btoa(`${username}:${Date.now()}`);
      console.log("✅ Authentication successful (temporary)");
      return { success: true, token: tempToken };
    }

    console.log("❌ Authentication failed");
    return { success: false };

    /* Future implementation with centralized API:
    const url = `${API_BASE}${RETAIL_API_PATH}/auth`;
    console.log("📡 Making POST request to:", url);
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ username, password }),
    });

    console.log("📡 Response status:", response.status);
    console.log("📡 Response ok:", response.ok);

    if (!response.ok) {
      console.log("❌ Authentication failed, response not ok");
      return { success: false };
    }

    const data = await response.json();
    console.log(
      "✅ Authentication successful, token received:",
      data.token ? "yes" : "no"
    );

    if (data.token) {
      localStorage.setItem("admin_token", data.token);
      console.log("💾 Token saved to localStorage");
    }

    return { success: true, token: data.token };
    */
  } catch (error) {
    console.error("💥 Error authenticating:", error);
    return { success: false };
  }
};
