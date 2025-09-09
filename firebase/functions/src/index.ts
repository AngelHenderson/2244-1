import { initializeApp } from "firebase-admin/app";
import { submitScore } from "./submitScore";

// Initialize Firebase Admin
initializeApp();

// Export Cloud Functions
export { submitScore };