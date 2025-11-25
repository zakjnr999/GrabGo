import 'package:grab_go_customer/features/status/model/status.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';

final List<StatusStory> demoStories = [
  StatusStory(
    restaurantName: 'Ramen Bowl',
    category: StatusCategory.dailySpecial,
    logo: Assets.images.sampleOne,
    statusCount: 2,
  ),
  StatusStory(
    restaurantName: 'Burger Hub',
    category: StatusCategory.discount,
    logo: Assets.images.sampleTwo,
    statusCount: 3,
    isViewed: true,
  ),
  StatusStory(
    restaurantName: 'Green Garden',
    category: StatusCategory.newItem,
    logo: Assets.images.sampleThree,
    statusCount: 4,
  ),
  StatusStory(
    restaurantName: 'Sushi Way',
    category: StatusCategory.video,
    logo: Assets.images.dishThree,
    statusCount: 3,
    isViewed: true,
  ),
];

final List<StatusPost> demoStatusPosts = [
  StatusPost(
    restaurantName: 'Ramen Bowl',
    category: StatusCategory.dailySpecial,
    timeAgo: '1h ago',
    coverImage: Assets.images.sampleOne,
    logoImage: Assets.images.dishOne,
    isRecommended: true,
  ),
  StatusPost(
    restaurantName: 'Burger Hub',
    category: StatusCategory.discount,
    timeAgo: '2h ago',
    coverImage: Assets.images.sampleTwo,
    logoImage: Assets.images.sampleTwo,
    isRecommended: true,
  ),
  StatusPost(
    restaurantName: 'Green Garden',
    category: StatusCategory.newItem,
    timeAgo: '3h ago',
    coverImage: Assets.images.sampleThree,
    logoImage: Assets.images.ingredientOne,
  ),
  StatusPost(
    restaurantName: 'Sushi Way',
    category: StatusCategory.video,
    timeAgo: '5h ago',
    coverImage: Assets.images.dishThree,
    logoImage: Assets.images.dishTwo,
    isRecommended: true,
  ),
];
