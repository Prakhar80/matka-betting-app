// Firebase Configuration
// Using the actual Firebase project configuration
const firebaseConfig = {
  apiKey: "AIzaSyDMkYPCKKjmBcGc9YsC5yO8vTUdsTmbf9w",
  authDomain: "matka-betting-app.firebaseapp.com", 
  projectId: "matka-betting-app",
  storageBucket: "matka-betting-app.appspot.com",
  messagingSenderId: "221882838219",
  appId: "1:221882838219:web:your-web-app-id",
  measurementId: "G-XXXXXXXXXX"
};

// Initialize Firebase
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const firestore = getFirestore(app);