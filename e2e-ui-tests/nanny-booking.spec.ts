import { test, expect } from "@playwright/test";

test.describe("Nanny Caregiver Booking UI Flow", () => {
  test.beforeEach(async ({ page }) => {
    // 1. Navigate to the root homepage
    await page.goto("/");
  });

  test("should display only 4h and 8h duration choices and support quote updates", async ({ page }) => {
    // 2. Click the Caregiver card on the homepage
    const caregiverCard = page.locator("button:has-text('Caregiver')");
    await expect(caregiverCard).toBeVisible();
    await caregiverCard.click();

    // 3. Verify that the general BookingDialog opens
    await expect(page.getByRole("heading", { name: "Select Booking Option" })).toBeVisible();

    // 4. Select the "On-demand" option (value "Date" radio)
    const onDemandRadio = page.locator("input[value='Date']");
    await onDemandRadio.click();

    // 5. Select the first available day from the datepicker grid
    const firstActiveDay = page.locator(".dtp-grid .dtp-day:not(.disabled):not(.empty)").first();
    await expect(firstActiveDay).toBeVisible();
    await firstActiveDay.click();

    // 6. Select the first available time slot button
    const firstActiveTime = page.locator(".dtp-time-grid .dtp-time:not(.disabled)").first();
    await expect(firstActiveTime).toBeVisible();
    await firstActiveTime.click();

    // 7. Click the Confirm button to save search criteria and load the provider list
    const confirmBtn = page.locator("button:has-text('Confirm')");
    await expect(confirmBtn).toBeVisible();
    await confirmBtn.click();

    // 8. Verify the UI transitioned to DetailsView (loading providers list)
    // We expect "Book Now" buttons on provider cards to become visible
    const bookNowButton = page.locator("button:has-text('Book Now'), button:has-text('Book')").first();
    await expect(bookNowButton).toBeVisible({ timeout: 10000 });
    await bookNowButton.click();

    // 9. Now inside NannyServicesDialog, verify caregiver duration choices are strictly 4h and 8h
    // We expect exactly two chips inside the duration chips container
    const durationChips = page.locator("[class*='durationChips'] button, [class*='durationChip']");
    await expect(durationChips).toHaveCount(2);

    const chip4h = durationChips.filter({ hasText: "4h" });
    const chip8h = durationChips.filter({ hasText: "8h" });
    await expect(chip4h).toBeVisible();
    await expect(chip8h).toBeVisible();

    // Verify other standard hours chips are NOT visible
    const chip1h = durationChips.filter({ hasText: "1h" });
    const chip2h = durationChips.filter({ hasText: "2h" });
    await expect(chip1h).not.toBeVisible();
    await expect(chip2h).not.toBeVisible();

    // 10. Verify 4h is selected by default (nanny caregiver default choice)
    await expect(chip4h).toHaveClass(/active|selected|durationChipActive/);

    // 11. Read initial price quote for 4h
    const priceTextContainer = page.locator("[class*='summaryValue'], [class*='priceDisplay'], [class*='PriceValue']").last();
    await expect(priceTextContainer).toBeVisible();
    const initialPriceText = await priceTextContainer.textContent();

    // 12. Toggle to 8h chip
    await chip8h.click();

    // 13. Verify selection updates to 8h
    await expect(chip8h).toHaveClass(/active|selected|durationChipActive/);
    await expect(chip4h).not.toHaveClass(/active|selected|durationChipActive/);

    // 14. Verify that the price quote updates (increases) accordingly
    await expect(async () => {
      const updatedPriceText = await priceTextContainer.textContent();
      expect(updatedPriceText).not.toBe(initialPriceText);
    }).toPass();
  });
});
