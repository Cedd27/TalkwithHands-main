import nodemailer from 'nodemailer';

let transporter;

function getTransporter() {
  if (!transporter) {
    transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.GMAIL_USER,
        pass: process.env.GMAIL_APP_PASSWORD, // Gmail App Password, not the account password
      },
    });
  }
  return transporter;
}

export async function sendOtpEmail(toEmail, otp) {
  await getTransporter().sendMail({
    from: `"Talk with Hands" <${process.env.GMAIL_USER}>`,
    to: toEmail,
    subject: 'Your password reset code',
    text: `Your reset code is ${otp}. It expires in 10 minutes.`,
    html: `<p>Your reset code is <b>${otp}</b>. It expires in 10 minutes.</p>`,
  });
}