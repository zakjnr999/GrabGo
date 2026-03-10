const {
  DeliveryProofUploadError,
  createOrderDeliveryProofHelpers,
} = require("../routes/support/order_delivery_proof_helpers");

describe("order_delivery_proof_helpers", () => {
  let deps;
  let helpers;

  beforeEach(() => {
    deps = {
      DELIVERY_ACTIVE_STATUSES: new Set(["confirmed", "preparing", "on_the_way"]),
      createOrderAudit: jest.fn(() => Promise.resolve()),
    };
    helpers = createOrderDeliveryProofHelpers(deps);
  });

  it("rejects unauthorized rider uploads", () => {
    expect(() =>
      helpers.ensureDeliveryProofUploadAllowed({
        order: {
          id: "order-1",
          riderId: "rider-a",
          status: "on_the_way",
          isGiftOrder: true,
          deliveryVerificationRequired: true,
        },
        actor: { id: "rider-b", role: "rider" },
        file: { cloudinaryUrl: "https://cdn.example/photo.jpg" },
      })
    ).toThrow(DeliveryProofUploadError);
  });

  it("rejects uploads without a cloudinary file URL", () => {
    expect(() =>
      helpers.ensureDeliveryProofUploadAllowed({
        order: {
          id: "order-2",
          riderId: "rider-a",
          status: "on_the_way",
          isGiftOrder: true,
          deliveryVerificationRequired: true,
        },
        actor: { id: "admin-1", role: "admin" },
        file: {},
      })
    ).toThrow(DeliveryProofUploadError);
  });

  it("records the proof upload audit and returns response data", async () => {
    const response = await helpers.recordDeliveryProofUpload({
      orderId: "order-3",
      actor: { id: "rider-1", role: "rider" },
      file: {
        cloudinaryUrl: "https://cdn.example/proof.jpg",
        blurHash: "LKO2?U%2Tw=w]~RBVZRi};RPxuwH",
      },
    });

    expect(deps.createOrderAudit).toHaveBeenCalledWith({
      orderId: "order-3",
      actorId: "rider-1",
      actorRole: "rider",
      action: "gift_delivery_photo_uploaded",
      metadata: expect.objectContaining({
        photoUrl: "https://cdn.example/proof.jpg",
      }),
    });
    expect(response).toEqual({
      orderId: "order-3",
      photoUrl: "https://cdn.example/proof.jpg",
      blurHash: "LKO2?U%2Tw=w]~RBVZRi};RPxuwH",
    });
  });
});
