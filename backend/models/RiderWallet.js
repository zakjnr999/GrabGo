const mongoose = require("mongoose");

const riderWalletSchema = new mongoose.Schema(
  {
    rider: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      unique: true,
    },
    balance: {
      type: Number,
      default: 0,
      min: 0,
    },
    totalEarnings: {
      type: Number,
      default: 0,
      min: 0,
    },
    totalWithdrawals: {
      type: Number,
      default: 0,
      min: 0,
    },
    pendingWithdrawals: {
      type: Number,
      default: 0,
      min: 0,
    },
    lastUpdated: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
  }
);

riderWalletSchema.methods.updateBalance = async function () {
  const Transaction = mongoose.model("Transaction");

  const earnings = await Transaction.aggregate([
    {
      $match: {
        rider: this.rider,
        status: "completed",
        type: { $in: ["delivery", "tip", "bonus"] },
      },
    },
    { $group: { _id: null, total: { $sum: "$amount" } } },
  ]);

  const withdrawals = await Transaction.aggregate([
    { $match: { rider: this.rider, type: "withdrawal" } },
    { $group: { _id: null, total: { $sum: "$amount" } } },
  ]);

  const pending = await Transaction.aggregate([
    { $match: { rider: this.rider, type: "withdrawal", status: "pending" } },
    { $group: { _id: null, total: { $sum: "$amount" } } },
  ]);

  this.totalEarnings = earnings[0]?.total || 0;
  this.totalWithdrawals = withdrawals[0]?.total || 0;
  this.pendingWithdrawals = pending[0]?.total || 0;
  this.balance = this.totalEarnings - this.totalWithdrawals;
  this.lastUpdated = new Date();

  return this.save();
};

module.exports = mongoose.model("RiderWallet", riderWalletSchema);
