/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

// Use centralized API
const API_BASE = import.meta.env.VITE_API_URL || "http://localhost:8080";
const API_PATH = "/api/v1"; // Legacy upload endpoints

export const uploadFile = async (file: File): Promise<string | null> => {
  try {
    const token = localStorage.getItem("admin_token");

    if (!token) {
      console.error("❌ No authentication token found");
      return null;
    }

    const formData = new FormData();
    formData.append("file", file);

    console.log("📤 Uploading file:", file.name, "Size:", file.size);

    const url = `${API_BASE}${API_PATH}/upload`;
    console.log("📡 Upload URL:", url);

    const response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
      },
      body: formData,
    });

    if (!response.ok) {
      console.error("❌ Upload failed, status:", response.status);
      const errorText = await response.text();
      console.error("❌ Response error text:", errorText);
      throw new Error("Failed to upload file");
    }

    const data = await response.json();
    console.log("✅ Upload successful:", data);

    // Return the URL from API response (already includes /uploads/ path)
    if (data.success && data.data && data.data.url) {
      // Return full URL using API base
      return `${API_BASE}${data.data.url}`;
    }

    console.error("❌ Invalid response format:", data);
    return null;
  } catch (error) {
    console.error("💥 Error uploading file:", error);
    return null;
  }
};

export const deleteFile = async (fileUrl: string): Promise<boolean> => {
  try {
    const token = localStorage.getItem("admin_token");

    if (!token) {
      console.error("❌ No authentication token found");
      return false;
    }

    // Extract filename from URL
    const filename = fileUrl.split("/").pop();
    if (!filename) {
      console.error("❌ Invalid file URL");
      return false;
    }

    console.log("🗑️  Deleting file:", filename);

    const url = `${API_BASE}${API_PATH}/upload/${filename}`;
    console.log("📡 Delete URL:", url);

    const response = await fetch(url, {
      method: "DELETE",
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      console.error("❌ Delete failed, status:", response.status);
      return false;
    }

    console.log("✅ File deleted successfully");
    return true;
  } catch (error) {
    console.error("💥 Error deleting file:", error);
    return false;
  }
};
