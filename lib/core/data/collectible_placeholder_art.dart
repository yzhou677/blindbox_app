/// DiceBear illustration URL for placeholder / mock collectibles (shared by features).
String placeholderCollectibleArtUrl(String seed, String backgroundHex) {
  return 'https://api.dicebear.com/9.x/thumbs/png'
      '?seed=${Uri.encodeComponent(seed)}'
      '&size=256'
      '&backgroundColor=$backgroundHex';
}
