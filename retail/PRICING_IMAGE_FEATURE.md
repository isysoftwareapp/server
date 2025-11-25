# Pricing Tier Image Upload Feature

## Summary of Changes

Added the ability to upload images for each pricing tier. These images are displayed **only in the modal** when users click the "Choose Plan" button, not on the landing page cards.

## Files Modified

### 1. `retail/types.ts`
- Added `image?: string` field to `PricingTier` interface
- This field stores the base64 encoded image data

### 2. `retail/App.tsx`
- Updated the Pricing Plan Modal to display the tier image
- Image is shown at the top of the modal with rounded corners and shadow
- Only displays if the image exists (`selectedPlan.image`)
- Styled with `h-64` height and `object-cover` for proper display

### 3. `retail/components/AdminPanel.tsx`
- Added image upload section in the pricing tab
- Features:
  - File upload input with drag-and-drop style UI
  - Preview of uploaded image (32rem height)
  - Delete button (appears on hover)
  - Converts images to base64 for storage
  - Clear visual feedback with gray dashed border

## How to Use

### For Admins:

1. Log in to the Admin Panel
2. Navigate to the "Pricing" tab
3. For each pricing tier, you'll see a new "Plan Image (Modal Only)" section
4. Click the upload area to select an image
5. The image will be displayed as a preview
6. Hover over the image and click the trash icon to remove it
7. Click "Save Changes" to persist the images

### User Experience:

1. On the landing page, pricing cards remain clean (no images)
2. When users click "Choose Plan" button
3. A modal opens showing:
   - **The uploaded image** (if available) at the top
   - Plan details (name, price, features)
   - Action buttons (Close, Get Started)

## Technical Details

- **Image Format**: Base64 encoded (stored in IndexedDB)
- **Supported Types**: All standard image formats (jpg, png, gif, webp, etc.)
- **Storage**: Images are stored with the site content in IndexedDB
- **Performance**: Images are loaded on-demand when modal opens

## Styling

- **Modal Image**: 
  - Full width
  - 16rem (256px) height
  - Object-fit: cover (maintains aspect ratio)
  - Rounded corners (0.5rem)
  - Shadow effect for depth

- **Upload Area**:
  - Dashed border (indicates upload zone)
  - Gray background when empty
  - Hover effect (border changes to brand color)
  - Icon and text centered

## Example Use Cases

1. **POS System**: Show an image of the POS interface
2. **KIOSK System**: Display a photo of the kiosk hardware
3. **Full Package**: Show both systems together in action

## Notes

- Images are optional - if no image is uploaded, the modal simply displays without one
- The landing page cards remain image-free for cleaner design
- Images are compressed and stored as base64, so keep file sizes reasonable
- Recommended image dimensions: 1200x800px or similar 3:2 ratio

## Future Enhancements

Potential improvements:
- Image size validation
- Image optimization/compression
- Multiple images per tier (gallery)
- Image URL support (instead of base64)
