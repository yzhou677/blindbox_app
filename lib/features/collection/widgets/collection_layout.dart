/// Responsive Pinterest-style grid density for the shelf.
int collectionGridCrossAxisCount(double width) {
  if (width >= 1000) return 4;
  if (width >= 680) return 3;
  return 2;
}
