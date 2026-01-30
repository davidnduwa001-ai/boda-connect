import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {Twilio} from "twilio";

// Initialize if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Region: us-central1 (default, most reliable)
const REGION = "us-central1";
const region = functions.region(REGION);

// Twilio configuration using environment variables
const twilioSid = process.env.TWILIO_ACCOUNT_SID;
const twilioToken = process.env.TWILIO_AUTH_TOKEN;
const twilioWhatsApp = process.env.TWILIO_WHATSAPP_NUMBER;

// Initialize Twilio client
const twilioClient = twilioSid && twilioToken ?
  new Twilio(twilioSid, twilioToken) : null;

// OTP Configuration
const OTP_LENGTH = 6;
const OTP_EXPIRY_MINUTES = 5;
const MAX_ATTEMPTS = 3;
const RESEND_COOLDOWN_SECONDS = 60;

/**
 * Generate a random OTP code
 * @param {number} length - Length of OTP
 * @return {string} OTP code
 */
function generateOTP(length: number): string {
  let otp = "";
  for (let i = 0; i < length; i++) {
    otp += Math.floor(Math.random() * 10).toString();
  }
  return otp;
}

/**
 * Format phone number to WhatsApp format
 * @param {string} phone - Phone number
 * @param {string} countryCode - Country code
 * @return {string} Formatted WhatsApp number
 */
function formatWhatsAppNumber(phone: string, countryCode = "+244"): string {
  let digits = phone.replace(/\D/g, "");

  if (digits.startsWith("244")) {
    digits = digits.substring(3);
  } else if (digits.startsWith("351")) {
    digits = digits.substring(3);
  }

  return `whatsapp:${countryCode}${digits}`;
}

// ==================== SEND OTP VIA WHATSAPP ====================

export const sendWhatsAppOTP = region.https.onCall(
    async (data) => {
      const {phone, countryCode = "+244"} = data;

      if (!phone) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Número de telefone é obrigatório"
        );
      }

      if (!twilioClient) {
        console.error("Twilio not configured. Check environment variables.");
        throw new functions.https.HttpsError(
            "failed-precondition",
            "Serviço de WhatsApp não configurado"
        );
      }

      const formattedPhone = formatWhatsAppNumber(phone, countryCode);
      const phoneHash = Buffer.from(formattedPhone).toString("base64");

      try {
        // Check for existing OTP and cooldown
        const existingDoc = await db
            .collection("whatsapp_otps")
            .doc(phoneHash)
            .get();

        if (existingDoc.exists) {
          const existingData = existingDoc.data();
          const lastSent = existingData?.lastSentAt?.toDate();

          if (lastSent) {
            const secondsSince = (Date.now() - lastSent.getTime()) / 1000;

            if (secondsSince < RESEND_COOLDOWN_SECONDS) {
              const wait = Math.ceil(RESEND_COOLDOWN_SECONDS - secondsSince);
              throw new functions.https.HttpsError(
                  "resource-exhausted",
                  `Aguarde ${wait} segundos para reenviar`
              );
            }
          }
        }

        // Generate OTP
        const otp = generateOTP(OTP_LENGTH);
        const expiresAt = new Date(
            Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000
        );

        // Store OTP in Firestore
        await db.collection("whatsapp_otps").doc(phoneHash).set({
          phone: formattedPhone,
          otp: otp,
          expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
          lastSentAt: admin.firestore.FieldValue.serverTimestamp(),
          attempts: 0,
          verified: false,
        });

        // Send WhatsApp message via Twilio
        const fromNumber = twilioWhatsApp || "whatsapp:+14155238886";

        await twilioClient.messages.create({
          body: "🔐 *BODA CONNECT*\n\n" +
            "Seu código de verificação é: *" + otp + "*\n\n" +
            "Este código expira em " + OTP_EXPIRY_MINUTES + " minutos.\n\n" +
            "Se você não solicitou este código, ignore esta mensagem.",
          from: fromNumber,
          to: formattedPhone,
        });

        console.log(`WhatsApp OTP sent to ${formattedPhone}`);

        return {
          success: true,
          message: "Código enviado via WhatsApp",
          expiresIn: OTP_EXPIRY_MINUTES * 60,
        };
      } catch (error: unknown) {
        console.error("Error sending WhatsApp OTP:", error);

        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            "Erro ao enviar código. Tente novamente."
        );
      }
    }
);

// ==================== VERIFY OTP ====================

export const verifyWhatsAppOTP = region.https.onCall(
    async (data) => {
      const {phone, otp, countryCode = "+244"} = data;

      if (!phone || !otp) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Telefone e código são obrigatórios"
        );
      }

      const formattedPhone = formatWhatsAppNumber(phone, countryCode);
      const phoneHash = Buffer.from(formattedPhone).toString("base64");

      try {
        const otpDoc = await db
            .collection("whatsapp_otps")
            .doc(phoneHash)
            .get();

        if (!otpDoc.exists) {
          throw new functions.https.HttpsError(
              "not-found",
              "Código não encontrado. Solicite um novo."
          );
        }

        const otpData = otpDoc.data();
        if (!otpData) {
          throw new functions.https.HttpsError(
              "not-found",
              "Código não encontrado. Solicite um novo."
          );
        }

        if (otpData.verified) {
          throw new functions.https.HttpsError(
              "already-exists",
              "Este código já foi utilizado"
          );
        }

        const expiresAt = otpData.expiresAt.toDate();
        if (new Date() > expiresAt) {
          await db.collection("whatsapp_otps").doc(phoneHash).delete();
          throw new functions.https.HttpsError(
              "deadline-exceeded",
              "Código expirado. Solicite um novo."
          );
        }

        if (otpData.attempts >= MAX_ATTEMPTS) {
          await db.collection("whatsapp_otps").doc(phoneHash).delete();
          throw new functions.https.HttpsError(
              "resource-exhausted",
              "Muitas tentativas. Solicite um novo código."
          );
        }

        if (otpData.otp !== otp) {
          await db.collection("whatsapp_otps").doc(phoneHash).update({
            attempts: admin.firestore.FieldValue.increment(1),
          });

          const remaining = MAX_ATTEMPTS - otpData.attempts - 1;
          throw new functions.https.HttpsError(
              "invalid-argument",
              `Código inválido. ${remaining} tentativas restantes.`
          );
        }

        // OTP is valid
        await db.collection("whatsapp_otps").doc(phoneHash).update({
          verified: true,
          verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const cleanPhone = formattedPhone.replace("whatsapp:", "");

        let userId: string;
        let isNewUser = false;

        try {
          const userRecord = await admin.auth()
              .getUserByPhoneNumber(cleanPhone);
          userId = userRecord.uid;
        } catch {
          const newUser = await admin.auth().createUser({
            phoneNumber: cleanPhone,
          });
          userId = newUser.uid;
          isNewUser = true;

          await db.collection("users").doc(userId).set({
            phone: cleanPhone,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            isActive: true,
            authMethod: "whatsapp",
          });
        }

        const customToken = await admin.auth().createCustomToken(userId);

        await db.collection("whatsapp_otps").doc(phoneHash).delete();

        console.log(`WhatsApp OTP verified for ${cleanPhone}`);

        return {
          success: true,
          token: customToken,
          userId: userId,
          isNewUser: isNewUser,
        };
      } catch (error: unknown) {
        console.error("Error verifying WhatsApp OTP:", error);

        if (error instanceof functions.https.HttpsError) {
          throw error;
        }

        throw new functions.https.HttpsError(
            "internal",
            "Erro ao verificar código"
        );
      }
    }
);

// ==================== RESEND OTP ====================

export const resendWhatsAppOTP = region.https.onCall(
    async (data) => {
      const {phone} = data;

      if (!phone) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Número de telefone é obrigatório"
        );
      }

      // Call sendWhatsAppOTP logic directly
      return sendWhatsAppOTP.run(data, {} as functions.https.CallableContext);
    }
);