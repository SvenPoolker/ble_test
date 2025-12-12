class MyItem {
  final String title;
  final String subtitle;
  final String icon;

  const MyItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  factory MyItem.fromJson(Map<String, dynamic> json) {
    return MyItem(
      title: (json['title'] as String?) ?? '',
      subtitle: (json['subtitle'] as String?) ?? '',
      icon: (json['icon'] as String?) ?? 'icon1.jpg',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'icon': icon,
    };
  }
}
