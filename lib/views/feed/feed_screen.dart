import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/profile/profile_screen.dart';

/// Community Feed - Social Media Platform for fitness content
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _storageService = Get.find<StorageService>();
  final Map<int, PageController> _pageControllers = {};

  // Mock feed data
  final List<Map<String, dynamic>> _feedPosts = [
    {
      'id': '1',
      'creator': 'Sarah Johnson',
      'creatorImage': 'SJ',
      'isTrainer': true,
      'isFollowing': true,
      'title': '5 Essential Squat Form Tips',
      'description': 'Master your squat technique with these crucial tips! 💪',
      'category': 'Workout',
      'tags': ['#squats', '#formcheck', '#legs'],
      'videoUrl': 'https://example.com/video1.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=400',
      'likes': 2847,
      'comments': 156,
      'shares': 89,
      'saves': 421,
      'isLiked': false,
      'isSaved': false,
      'isPremium': true,
      'isFavorited': true,
      'timestamp': '2 hours ago',
      'duration': '45s',
    },
    {
      'id': '2',
      'creator': 'Mike Chen',
      'creatorImage': 'MC',
      'isTrainer': true,
      'isFollowing': false,
      'title': 'Meal Prep Sunday: High Protein Bowls',
      'description': 'Easy meal prep for the week! 🍗🥗',
      'category': 'Nutrition',
      'tags': ['#mealprep', '#nutrition', '#healthyeating'],
      'videoUrl': 'https://example.com/video2.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400',
      'likes': 1923,
      'comments': 87,
      'shares': 145,
      'saves': 892,
      'isLiked': true,
      'isSaved': true,
      'isPremium': true,
      'isFavorited': true,
      'timestamp': '4 hours ago',
      'duration': '1:15',
    },
    {
      'id': '3',
      'creator': 'Emma Davis',
      'creatorImage': 'ED',
      'isTrainer': false,
      'isFollowing': true,
      'title': 'Morning Run Motivation',
      'description': 'Nothing beats a sunrise run! 🌅🏃‍♀️',
      'category': 'Running',
      'tags': ['#running', '#motivation', '#morningrun'],
      'videoUrl': 'https://example.com/video3.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=400',
      'likes': 3421,
      'comments': 234,
      'shares': 67,
      'saves': 156,
      'isLiked': false,
      'isSaved': false,
      'isPremium': false,
      'isFavorited': false,
      'timestamp': '8 hours ago',
      'duration': '30s',
    },
    {
      'id': '4',
      'creator': 'Alex Rodriguez',
      'creatorImage': 'AR',
      'isTrainer': true,
      'isFollowing': true,
      'title': 'Basketball Dribbling Drills',
      'description': 'Level up your handles with these drills! 🏀',
      'category': 'Sports',
      'tags': ['#basketball', '#training', '#skills'],
      'videoUrl': 'https://example.com/video4.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=400',
      'likes': 1567,
      'comments': 92,
      'shares': 78,
      'saves': 234,
      'isLiked': true,
      'isSaved': false,
      'isPremium': true,
      'isFavorited': true,
      'timestamp': '1 day ago',
      'duration': '1:00',
    },
    {
      'id': '5',
      'creator': 'Lisa Thompson',
      'creatorImage': 'LT',
      'isTrainer': true,
      'isFollowing': false,
      'title': 'Full Body Mobility Routine',
      'description': 'Improve flexibility and reduce injury risk 🧘‍♀️',
      'category': 'Mobility',
      'tags': ['#mobility', '#flexibility', '#recovery'],
      'videoUrl': 'https://example.com/video5.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400',
      'likes': 2134,
      'comments': 143,
      'shares': 112,
      'saves': 567,
      'isLiked': false,
      'isSaved': true,
      'isPremium': false,
      'isFavorited': false,
      'timestamp': '1 day ago',
      'duration': '1:20',
    },
    {
      'id': '6',
      'creator': 'David Park',
      'creatorImage': 'DP',
      'isTrainer': true,
      'isFollowing': true,
      'title': 'Deadlift Mastery: Perfect Your Form',
      'description': 'Learn the fundamentals of proper deadlift technique 💀',
      'category': 'Strength',
      'tags': ['#deadlift', '#strength', '#form'],
      'videoUrl': 'https://example.com/video6.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400',
      'likes': 3456,
      'comments': 198,
      'shares': 123,
      'saves': 789,
      'isLiked': true,
      'isSaved': false,
      'isPremium': true,
      'isFavorited': true,
      'timestamp': '2 days ago',
      'duration': '2:30',
    },
    {
      'id': '7',
      'creator': 'Jessica Martinez',
      'creatorImage': 'JM',
      'isTrainer': false,
      'isFollowing': false,
      'title': 'Yoga Flow for Beginners',
      'description': 'Start your yoga journey with this gentle flow 🧘',
      'category': 'Yoga',
      'tags': ['#yoga', '#beginner', '#flexibility'],
      'videoUrl': 'https://example.com/video7.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=400',
      'likes': 1876,
      'comments': 89,
      'shares': 45,
      'saves': 234,
      'isLiked': false,
      'isSaved': false,
      'isPremium': false,
      'isFavorited': false,
      'timestamp': '2 days ago',
      'duration': '15:00',
    },
    {
      'id': '8',
      'creator': 'Tom Wilson',
      'creatorImage': 'TW',
      'isTrainer': true,
      'isFollowing': true,
      'title': 'HIIT Cardio Blast',
      'description': '20 minutes of high-intensity cardio 🔥',
      'category': 'Cardio',
      'tags': ['#hiit', '#cardio', '#fatburn'],
      'videoUrl': 'https://example.com/video8.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400',
      'likes': 4123,
      'comments': 267,
      'shares': 189,
      'saves': 1023,
      'isLiked': true,
      'isSaved': true,
      'isPremium': true,
      'isFavorited': true,
      'timestamp': '3 days ago',
      'duration': '20:00',
    },
    {
      'id': '9',
      'creator': 'Maria Garcia',
      'creatorImage': 'MG',
      'isTrainer': true,
      'isFollowing': false,
      'title': 'Healthy Smoothie Recipes',
      'description': '5 delicious and nutritious smoothie recipes 🥤',
      'category': 'Nutrition',
      'tags': ['#smoothie', '#nutrition', '#healthy'],
      'videoUrl': 'https://example.com/video9.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=400',
      'likes': 2987,
      'comments': 156,
      'shares': 234,
      'saves': 678,
      'isLiked': false,
      'isSaved': true,
      'isPremium': false,
      'isFavorited': false,
      'timestamp': '3 days ago',
      'duration': '5:45',
    },
    {
      'id': '10',
      'creator': 'Chris Anderson',
      'creatorImage': 'CA',
      'isTrainer': false,
      'isFollowing': true,
      'title': 'Swimming Technique Tips',
      'description': 'Improve your swimming form and speed 🏊',
      'category': 'Swimming',
      'tags': ['#swimming', '#technique', '#endurance'],
      'videoUrl': 'https://example.com/video10.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1530549387789-4c1017266635?w=400',
      'likes': 1654,
      'comments': 78,
      'shares': 56,
      'saves': 189,
      'isLiked': false,
      'isSaved': false,
      'isPremium': false,
      'isFavorited': false,
      'timestamp': '4 days ago',
      'duration': '8:20',
    },
    {
      'id': '11',
      'creator': 'Rachel Kim',
      'creatorImage': 'RK',
      'isTrainer': true,
      'isFollowing': true,
      'title': 'Pilates Core Strengthening',
      'description': 'Build a strong core with these Pilates moves 💪',
      'category': 'Pilates',
      'tags': ['#pilates', '#core', '#strength'],
      'videoUrl': 'https://example.com/video11.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400',
      'likes': 2234,
      'comments': 134,
      'shares': 98,
      'saves': 456,
      'isLiked': true,
      'isSaved': false,
      'isPremium': true,
      'isFavorited': true,
      'timestamp': '4 days ago',
      'duration': '12:15',
    },
    {
      'id': '12',
      'creator': 'James Brown',
      'creatorImage': 'JB',
      'isTrainer': true,
      'isFollowing': false,
      'title': 'Boxing Fundamentals',
      'description': 'Learn basic boxing punches and footwork 🥊',
      'category': 'Boxing',
      'tags': ['#boxing', '#martialarts', '#training'],
      'videoUrl': 'https://example.com/video12.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=400',
      'likes': 3789,
      'comments': 245,
      'shares': 167,
      'saves': 890,
      'isLiked': false,
      'isSaved': true,
      'isPremium': true,
      'isFavorited': true,
      'timestamp': '5 days ago',
      'duration': '10:30',
    },
    {
      'id': '13',
      'creator': 'Sophie Lee',
      'creatorImage': 'SL',
      'isTrainer': false,
      'isFollowing': true,
      'title': 'Cycling Training Tips',
      'description': 'Boost your cycling performance 🚴‍♀️',
      'category': 'Cycling',
      'tags': ['#cycling', '#endurance', '#training'],
      'videoUrl': 'https://example.com/video13.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400',
      'likes': 1456,
      'comments': 67,
      'shares': 34,
      'saves': 123,
      'isLiked': false,
      'isSaved': false,
      'isPremium': false,
      'isFavorited': false,
      'timestamp': '5 days ago',
      'duration': '6:45',
    },
    {
      'id': '14',
      'creator': 'Michael Taylor',
      'creatorImage': 'MT',
      'isTrainer': true,
      'isFollowing': true,
      'title': 'Pull-Up Progression Guide',
      'description': 'Master pull-ups from zero to hero 💪',
      'category': 'Calisthenics',
      'tags': ['#pullups', '#calisthenics', '#bodyweight'],
      'videoUrl': 'https://example.com/video14.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400',
      'likes': 4567,
      'comments': 312,
      'shares': 234,
      'saves': 1234,
      'isLiked': true,
      'isSaved': true,
      'isPremium': true,
      'isFavorited': true,
      'timestamp': '6 days ago',
      'duration': '9:15',
    },
    {
      'id': '15',
      'creator': 'Amanda White',
      'creatorImage': 'AW',
      'isTrainer': true,
      'isFollowing': false,
      'title': 'Meditation for Athletes',
      'description': 'Mental training for peak performance 🧘‍♂️',
      'category': 'Mental Health',
      'tags': ['#meditation', '#mentalhealth', '#recovery'],
      'videoUrl': 'https://example.com/video15.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=400',
      'likes': 1890,
      'comments': 98,
      'shares': 76,
      'saves': 345,
      'isLiked': false,
      'isSaved': false,
      'isPremium': false,
      'isFavorited': false,
      'timestamp': '6 days ago',
      'duration': '15:30',
    },
    {
      'id': '16',
      'creator': 'Ryan Murphy',
      'creatorImage': 'RM',
      'isTrainer': false,
      'isFollowing': true,
      'title': 'Rock Climbing Basics',
      'description': 'Get started with indoor rock climbing 🧗',
      'category': 'Rock Climbing',
      'tags': ['#climbing', '#adventure', '#strength'],
      'videoUrl': 'https://example.com/video16.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400',
      'likes': 2345,
      'comments': 145,
      'shares': 89,
      'saves': 567,
      'isLiked': true,
      'isSaved': false,
      'isPremium': false,
      'isFavorited': false,
      'timestamp': '1 week ago',
      'duration': '11:20',
    },
    {
      'id': '17',
      'creator': 'Nicole Foster',
      'creatorImage': 'NF',
      'isTrainer': true,
      'isFollowing': true,
      'title': 'Kettlebell Workout Routine',
      'description': 'Full body workout with kettlebells 🔔',
      'category': 'Strength',
      'tags': ['#kettlebell', '#strength', '#fullbody'],
      'videoUrl': 'https://example.com/video17.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400',
      'likes': 3124,
      'comments': 189,
      'shares': 145,
      'saves': 789,
      'isLiked': false,
      'isSaved': true,
      'isPremium': true,
      'isFavorited': true,
      'timestamp': '1 week ago',
      'duration': '18:45',
    },
    {
      'id': '18',
      'creator': 'Kevin Zhang',
      'creatorImage': 'KZ',
      'isTrainer': true,
      'isFollowing': false,
      'title': 'Protein-Rich Meal Ideas',
      'description': 'High protein meals for muscle building 🍖',
      'category': 'Nutrition',
      'tags': ['#protein', '#nutrition', '#musclebuilding'],
      'videoUrl': 'https://example.com/video18.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400',
      'likes': 2678,
      'comments': 167,
      'shares': 234,
      'saves': 890,
      'isLiked': true,
      'isSaved': false,
      'isPremium': false,
      'isFavorited': false,
      'timestamp': '1 week ago',
      'duration': '7:30',
    },
    {
      'id': '19',
      'creator': 'Olivia Green',
      'creatorImage': 'OG',
      'isTrainer': false,
      'isFollowing': true,
      'title': 'Dance Cardio Workout',
      'description': 'Fun dance moves that burn calories 💃',
      'category': 'Cardio',
      'tags': ['#dance', '#cardio', '#fun'],
      'videoUrl': 'https://example.com/video19.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=400',
      'likes': 3456,
      'comments': 234,
      'shares': 189,
      'saves': 678,
      'isLiked': false,
      'isSaved': false,
      'isPremium': false,
      'isFavorited': false,
      'timestamp': '1 week ago',
      'duration': '25:00',
    },
    {
      'id': '20',
      'creator': 'Daniel Cooper',
      'creatorImage': 'DC',
      'isTrainer': true,
      'isFollowing': true,
      'title': 'Stretching Routine for Runners',
      'description': 'Essential stretches to prevent injuries 🏃',
      'category': 'Stretching',
      'tags': ['#stretching', '#running', '#recovery'],
      'videoUrl': 'https://example.com/video20.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=400',
      'likes': 2789,
      'comments': 156,
      'shares': 98,
      'saves': 456,
      'isLiked': true,
      'isSaved': true,
      'isPremium': true,
      'isFavorited': true,
      'timestamp': '1 week ago',
      'duration': '14:20',
    },
    {
      'id': '21',
      'creator': 'Laura Mitchell',
      'creatorImage': 'LM',
      'isTrainer': true,
      'isFollowing': false,
      'title': 'TRX Suspension Training',
      'description': 'Full body workout using TRX straps 🎯',
      'category': 'Functional Training',
      'tags': ['#trx', '#functionaltraining', '#core'],
      'videoUrl': 'https://example.com/video21.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400',
      'likes': 1890,
      'comments': 112,
      'shares': 78,
      'saves': 345,
      'isLiked': false,
      'isSaved': false,
      'isPremium': false,
      'isFavorited': false,
      'timestamp': '2 weeks ago',
      'duration': '16:45',
    },
    {
      'id': '22',
      'creator': 'Robert King',
      'creatorImage': 'RK',
      'isTrainer': false,
      'isFollowing': true,
      'title': 'Marathon Training Tips',
      'description': 'How to prepare for your first marathon 🏃‍♂️',
      'category': 'Running',
      'tags': ['#marathon', '#running', '#endurance'],
      'videoUrl': 'https://example.com/video22.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=400',
      'likes': 4123,
      'comments': 298,
      'shares': 234,
      'saves': 1234,
      'isLiked': true,
      'isSaved': false,
      'isPremium': false,
      'isFavorited': false,
      'timestamp': '2 weeks ago',
      'duration': '12:00',
    },
    {
      'id': '23',
      'creator': 'Jennifer Adams',
      'creatorImage': 'JA',
      'isTrainer': true,
      'isFollowing': true,
      'title': 'Post-Workout Recovery Smoothie',
      'description': 'Perfect smoothie to refuel after training 🥤',
      'category': 'Nutrition',
      'tags': ['#recovery', '#smoothie', '#postworkout'],
      'videoUrl': 'https://example.com/video23.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=400',
      'likes': 2234,
      'comments': 145,
      'shares': 167,
      'saves': 678,
      'isLiked': false,
      'isSaved': true,
      'isPremium': true,
      'isFavorited': true,
      'timestamp': '2 weeks ago',
      'duration': '3:45',
    },
    {
      'id': '24',
      'creator': 'Mark Stevens',
      'creatorImage': 'MS',
      'isTrainer': true,
      'isFollowing': false,
      'title': 'Olympic Lifting Basics',
      'description': 'Introduction to snatch and clean & jerk 🏋️',
      'category': 'Olympic Lifting',
      'tags': ['#olympiclifting', '#strength', '#technique'],
      'videoUrl': 'https://example.com/video24.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400',
      'likes': 5678,
      'comments': 412,
      'shares': 298,
      'saves': 1890,
      'isLiked': true,
      'isSaved': false,
      'isPremium': true,
      'isFavorited': true,
      'timestamp': '2 weeks ago',
      'duration': '22:30',
    },
    {
      'id': '25',
      'creator': 'Patricia Moore',
      'creatorImage': 'PM',
      'isTrainer': false,
      'isFollowing': true,
      'title': 'Outdoor Hiking Adventure',
      'description': 'Beautiful trails and hiking tips 🥾',
      'category': 'Hiking',
      'tags': ['#hiking', '#outdoor', '#adventure'],
      'videoUrl': 'https://example.com/video25.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400',
      'likes': 3456,
      'comments': 234,
      'shares': 189,
      'saves': 890,
      'isLiked': false,
      'isSaved': false,
      'isPremium': false,
      'isFavorited': false,
      'timestamp': '3 weeks ago',
      'duration': '18:15',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var controller in _pageControllers.values) {
      controller.dispose();
    }
    _pageControllers.clear();
    super.dispose();
  }

  PageController _getPageController(int tabIndex) {
    if (!_pageControllers.containsKey(tabIndex)) {
      _pageControllers[tabIndex] = PageController();
    }
    return _pageControllers[tabIndex]!;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.backgroundColor, AppColors.backgroundColor, AppColors.backgroundColor]),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Obx(() {
            final notificationController = Get.find<NotificationController>();
            final unreadCount = notificationController.unreadCount;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Image.asset('assets/images/humburger1.png'),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ).paddingOnly(left: 10),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1.0),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          }),
          title: AnimatedBuilder(
            animation: _tabController,
            builder: (context, child) {
              String titleText;
              switch (_tabController.index) {
                case 0:
                  titleText = 'For You';
                  break;
                case 1:
                  titleText = 'Following';
                  break;
                case 2:
                  titleText = 'Profile';
                  break;
                default:
                  titleText = 'Community Feed';
              }
              return Text(titleText, style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w900));
            },
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Image.asset('assets/images/search.png', width: 20.w),
              onPressed: () {
                _showSearchScreen();
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            unselectedLabelColor: const Color(0xFF404040),
            tabs: [
              Tab(icon: Icon(Icons.public)),
              Tab(icon: Icon(Icons.people)),
              Tab(icon: Icon(Icons.person)),
            ],
          ),
        ),
        body: TabBarView(controller: _tabController, children: [_buildForYouFeed(), _buildFollowingFeed(), _buildProfilePage()]),
      ),
    );
  }

  Widget _buildForYouFeed() {
    return PageView.builder(
      controller: _getPageController(0),
      scrollDirection: Axis.vertical,
      itemCount: _feedPosts.length,
      itemBuilder: (context, index) {
        return _buildFullScreenPost(_feedPosts[index]);
      },
    );
  }

  Widget _buildFollowingFeed() {
    final followingPosts = _feedPosts.where((post) => post['isFollowing'] == true).toList();

    if (followingPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: AppColors.primaryGray.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('No posts from followed creators', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _tabController.animateTo(2);
              },
              child: const Text('Discover Creators'),
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      controller: _getPageController(1),
      scrollDirection: Axis.vertical,
      itemCount: followingPosts.length,
      itemBuilder: (context, index) {
        return _buildFullScreenPost(followingPosts[index]);
      },
    );
  }

  Widget _buildProfilePage() {
    // Return the ProfileScreen widget without AppBar and tabs, showing only Public content
    return const ProfileScreen(hideAppBar: true, showOnlyPublic: true);
  }

  void _showSearchScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SearchScreen(allPosts: _feedPosts, onPostTap: (post) => _showPostDetail(post), buildExploreGridItem: (post) => _buildExploreGridItem(post)),
      ),
    );
  }

  Widget _buildExploreGridItem(Map<String, dynamic> post) {
    final isTrainer = post['isTrainer'] ?? false;
    final isCertified = isTrainer; // Show verified/certified icon if trainer

    return GestureDetector(
      onTap: () => _openVideoReel(post),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail image
          Image.network(
            post['thumbnail'],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF9333EA), const Color(0xFFFBBF24)]),
              ),
            ),
          ),

          // Gradient overlay for better visibility
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.2)]),
            ),
          ),

          // White circular play button in center
          Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)],
              ),
              child: Icon(Icons.play_arrow, color: AppColors.accent, size: 24),
            ),
          ),

          // Verified/Certified icon in top-right corner (only shown if trainer/certified)
          if (isCertified)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: const Color.fromARGB(153, 71, 71, 71), shape: BoxShape.circle),
                child: Icon(
                  Icons.verified,
                  color: AppColors.completed, // Blue/Green color for verified
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullScreenPost(Map<String, dynamic> post) {
    return GestureDetector(
      onTap: () => _showPostDetail(post),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full screen background image/video
          Image.network(
            post['thumbnail'],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF9333EA), const Color(0xFFFBBF24)]),
              ),
            ),
          ),

          // Gradient overlay for better text visibility
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.6)],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),

          // Large white circular play button in center
          Center(
            child: GestureDetector(
              onTap: () => _openVideoReel(post),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
                ),
                child: Icon(Icons.play_arrow, color: AppColors.accent, size: 50),
              ),
            ),
          ),

          // Top right duration badge
          Positioned(
            top: 20,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(6)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_outline, color: Colors.white, size: 17),
                  const SizedBox(width: 4),
                  Text(
                    post['duration'] ?? '30s',
                    style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

          // Right side interaction buttons
          Positioned(
            right: 16,
            bottom: 70,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile Avatar
                GestureDetector(
                  onTap: () => _navigateToCreatorProfile(post),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.accent.withOpacity(0.2),
                      child: Text(
                        post['creatorImage'] ?? 'U',
                        style: AppTextStyles.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),

                // Like button
                _buildVerticalInteractionButton(
                  icon: post['isLiked'] ? Icons.favorite : Icons.favorite_border,
                  count: post['likes'] ?? 0,
                  color: post['isLiked'] ? Colors.red : Colors.white,
                  onTap: () {
                    setState(() {
                      post['isLiked'] = !post['isLiked'];
                      post['likes'] += post['isLiked'] ? 1 : -1;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Comment button
                _buildVerticalInteractionButton(icon: Icons.comment_outlined, count: post['comments'] ?? 0, color: Colors.white, onTap: () => _showComments(post)),
                const SizedBox(height: 20),

                // Save/Bookmark button
                _buildVerticalInteractionButton(
                  icon: post['isSaved'] ? Icons.bookmark : Icons.bookmark_border,
                  count: post['saves'] ?? 0,
                  color: Colors.white,
                  onTap: () async {
                    final isSaved = post['isSaved'] ?? false;
                    setState(() {
                      post['isSaved'] = !isSaved;
                      post['saves'] += !isSaved ? 1 : -1;
                    });
                    if (!isSaved) {
                      await _storageService.addSavedPost(post);
                    } else {
                      await _storageService.removeSavedPost(post['id']);
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Share button
                _buildVerticalInteractionButton(icon: Icons.share_outlined, count: post['shares'] ?? 0, color: Colors.white, onTap: () => _showShareOptions(post)),
                const SizedBox(height: 20),

                // Premium star icon
                GestureDetector(
                  onTap: () {
                    // TODO: Handle premium/favorite action
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Color.fromARGB(255, 145, 123, 2), shape: BoxShape.circle),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          color: AppColors.white, // Gold color for premium
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom left text content
          Positioned(
            left: 16,
            bottom: 15,
            right: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Username
                GestureDetector(
                  onTap: () => _navigateToCreatorProfile(post),
                  child: Row(
                    children: [
                      Text(
                        '@${(post['creator'] ?? 'user').toString().toLowerCase().replaceAll(' ', '')}',
                        style: AppTextStyles.titleSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                      ),
                      if (post['isTrainer'])
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(Icons.verified, color: AppColors.completed, size: 18),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Caption
                Text(
                  post['description'] ?? '',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontSize: 14,
                    shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                ),
                const SizedBox(height: 8),

                // Hashtags
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children:
                      (post['tags'] as List<String>?)
                          ?.map(
                            (tag) => Text(
                              tag,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 6, offset: const Offset(0, 2))],
                              ),
                            ),
                          )
                          .toList() ??
                      [],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalInteractionButton({required IconData icon, required int count, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            _formatCount(count),
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 4, offset: const Offset(0, 1))],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedPost(Map<String, dynamic> post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: GestureDetector(
              onTap: () => _navigateToCreatorProfile(post),
              child: CircleAvatar(
                backgroundColor: AppColors.accent.withOpacity(0.2),
                child: Text(post['creatorImage'], style: AppTextStyles.titleSmall.copyWith(color: AppColors.accent)),
              ),
            ),
            title: InkWell(
              onTap: () => _navigateToCreatorProfile(post),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Text(
                    post['creator'],
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                  ),
                  if (post['isTrainer'])
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.verified, color: AppColors.completed, size: 16),
                    ),
                ],
              ),
            ),
            subtitle: Text('${post['timestamp']} • ${post['category']}', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
            trailing: PopupMenuButton(
              icon: Icon(Icons.more_vert, color: AppColors.primaryGray),
              itemBuilder: (context) => [
                PopupMenuItem(child: Text('Save Post'), value: 'save'),
                PopupMenuItem(child: Text('Share'), value: 'share'),
                if (!post['isFollowing']) PopupMenuItem(child: Text('Follow ${post['creator']}'), value: 'follow'),
                PopupMenuItem(child: Text('Report'), value: 'report'),
              ],
              onSelected: (value) {
                _handlePostAction(value.toString(), post);
              },
            ),
          ),

          GestureDetector(
            onTap: () => _showPostDetail(post),
            child: Stack(
              children: [
                Stack(
                  children: [
                    Image.network(
                      post['thumbnail'],
                      width: double.infinity,
                      height: 400,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: double.infinity,
                        height: 400,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF9333EA), const Color(0xFFFBBF24)]),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      height: 400,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.5)]),
                      ),
                    ),
                    Positioned.fill(
                      child: Center(child: Icon(Icons.play_circle_filled, size: 80, color: Colors.white.withOpacity(0.9))),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['title'],
                        style: AppTextStyles.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post['description'],
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
                    child: Text(post['duration'], style: AppTextStyles.labelSmall.copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildInteractionButton(
                        icon: post['isLiked'] ? Icons.favorite : Icons.favorite_border,
                        label: _formatCount(post['likes']),
                        color: post['isLiked'] ? AppColors.error : AppColors.primaryGray,
                        onTap: () {
                          setState(() {
                            post['isLiked'] = !post['isLiked'];
                            post['likes'] += post['isLiked'] ? 1 : -1;
                          });
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildInteractionButton(icon: Icons.comment_outlined, label: _formatCount(post['comments']), color: AppColors.primaryGray, onTap: () => _showComments(post)),
                      const SizedBox(width: 16),
                      _buildInteractionButton(
                        icon: post['isSaved'] ? Icons.bookmark : Icons.bookmark_border,
                        label: _formatCount(post['saves']),
                        color: post['isSaved'] ? AppColors.accent : AppColors.primaryGray,
                        onTap: () async {
                          final isSaved = post['isSaved'] ?? false;
                          setState(() {
                            post['isSaved'] = !isSaved;
                            post['saves'] += !isSaved ? 1 : -1;
                          });
                          if (!isSaved) {
                            await _storageService.addSavedPost(post);
                          } else {
                            await _storageService.removeSavedPost(post['id']);
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildInteractionButton(icon: Icons.share_outlined, label: _formatCount(post['shares']), color: AppColors.primaryGray, onTap: () => _showShareOptions(post)),
                    ],
                  ),
                ),
                if (post['isTrainer']) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Navigate to trainer profile with hire option
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      textStyle: AppTextStyles.labelSmall.copyWith(fontSize: 12),
                    ),
                    child: const Text('Hire Me'),
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: (post['tags'] as List<String>).map((tag) {
                return Text(
                  tag,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _navigateToCreatorProfile(Map<String, dynamic> post) {
    final String creatorName = (post['creator'] ?? 'Creator').toString();
    final String initials = (post['creatorImage'] ?? 'UT').toString();
    final bool isTrainer = post['isTrainer'] == true;
    final String category = (post['category'] ?? 'Fitness').toString();

    final trainerData = <String, dynamic>{
      'id': creatorName.toLowerCase().replaceAll(' ', '_'),
      'name': creatorName,
      'initials': initials,
      'bio': isTrainer
          ? 'Certified trainer sharing ${category.toLowerCase()} tips and routines to help you reach your goals.'
          : 'Fitness enthusiast sharing ${category.toLowerCase()} content with the community.',
      'specialties': <String>[category, 'Training', if (isTrainer) 'Coaching'],
      'yearsOfExperience': isTrainer ? 6 : 2,
      'certified': isTrainer,
      'certifications': isTrainer ? ['Certified Personal Trainer'] : null,
      'hourlyRate': 75.0,
      'rating': 4.8,
      'totalReviews': 127,
      'students': 1250,
      'activePrograms': 5,
      'completedPrograms': 12,
      'totalPrograms': 17,
    };

    Get.toNamed(AppRoutes.trainerProfile, arguments: trainerData);
  }

  Widget _buildInteractionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelMedium.copyWith(color: color)),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  void _showCreatePostOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Create Post', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface)),
            const SizedBox(height: 24),
            _buildCreateOption(Icons.videocam, 'Record Video', 'Capture a new video', () {
              Navigator.pop(context);
              Get.toNamed(AppRoutes.createPost, arguments: {'type': 'record'});
            }),
            _buildCreateOption(Icons.video_library, 'Upload Video', 'Choose from gallery', () {
              Navigator.pop(context);
              Get.toNamed(AppRoutes.createPost, arguments: {'type': 'video'});
            }),
            _buildCreateOption(Icons.image, 'Upload Photo', 'Share a static image', () {
              Navigator.pop(context);
              Get.toNamed(AppRoutes.createPost, arguments: {'type': 'image'});
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateOption(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppColors.accent),
      ),
      title: Text(title, style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface)),
      subtitle: Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.primaryGray),
      onTap: onTap,
    );
  }

  void _showPostDetail(Map<String, dynamic> post) {
    Get.snackbar('Post Detail', 'Opening ${post['title']}', backgroundColor: AppColors.accent, colorText: AppColors.onAccent, snackPosition: SnackPosition.BOTTOM);
  }

  void _openVideoReel(Map<String, dynamic> post) {
    // Find the index of the current post
    final currentIndex = _feedPosts.indexWhere((p) => p['id'] == post['id']);

    // Navigate to video reel screen with all posts and current index
    Get.toNamed(AppRoutes.videoReel, arguments: {'posts': _feedPosts, 'initialIndex': currentIndex >= 0 ? currentIndex : 0});
  }

  void _showComments(Map<String, dynamic> post) {
    Get.snackbar('Comments', '${post['comments']} comments', backgroundColor: AppColors.accent, colorText: AppColors.onAccent, snackPosition: SnackPosition.BOTTOM);
  }

  void _showShareOptions(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share Post', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [_buildShareIcon(Icons.message, 'Message', () {}), _buildShareIcon(Icons.link, 'Copy Link', () {}), _buildShareIcon(Icons.share, 'More', () {})],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildShareIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.accent, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface)),
        ],
      ),
    );
  }

  void _handlePostAction(String action, Map<String, dynamic> post) async {
    switch (action) {
      case 'save':
        final isSaved = post['isSaved'] ?? false;
        setState(() {
          post['isSaved'] = !isSaved;
        });
        if (!isSaved) {
          await _storageService.addSavedPost(post);
        } else {
          await _storageService.removeSavedPost(post['id']);
        }
        Get.snackbar(
          !isSaved ? 'Saved' : 'Unsaved',
          !isSaved ? 'Post saved to your collection' : 'Post removed from collection',
          backgroundColor: AppColors.accent,
          colorText: AppColors.onAccent,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
        break;
      case 'follow':
        setState(() {
          post['isFollowing'] = true;
        });
        Get.snackbar(
          'Following',
          'You are now following ${post['creator']}',
          backgroundColor: AppColors.completed,
          colorText: AppColors.onError,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
        break;
      case 'report':
        _showReportDialog(post);
        break;
      case 'share':
        _showShareOptions(post);
        break;
    }
  }

  void _showReportDialog(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Report Post', style: AppTextStyles.titleLarge.copyWith()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_buildReportOption('Inappropriate content'), _buildReportOption('Misleading advice'), _buildReportOption('Spam'), _buildReportOption('Harassment')],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.primaryGray)),
          ),
        ],
      ),
    );
  }

  Widget _buildReportOption(String reason) {
    return ListTile(
      title: Text(reason, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
      onTap: () {
        Navigator.pop(context);
        Get.snackbar(
          'Report Submitted',
          'Thank you for keeping our community safe',
          backgroundColor: AppColors.completed,
          colorText: AppColors.onError,
          snackPosition: SnackPosition.BOTTOM,
        );
      },
    );
  }
}

/// Search Screen - Shows search bar with explore content
class _SearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allPosts;
  final ValueChanged<Map<String, dynamic>> onPostTap;
  final Widget Function(Map<String, dynamic>) buildExploreGridItem;

  const _SearchScreen({required this.allPosts, required this.onPostTap, required this.buildExploreGridItem});

  @override
  State<_SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<_SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredPosts {
    if (_searchQuery.isEmpty) {
      return widget.allPosts;
    }
    final query = _searchQuery.toLowerCase();
    return widget.allPosts.where((post) {
      final title = (post['title'] ?? '').toString().toLowerCase();
      final description = (post['description'] ?? '').toString().toLowerCase();
      final category = (post['category'] ?? '').toString().toLowerCase();
      final creator = (post['creator'] ?? '').toString().toLowerCase();
      final tags = (post['tags'] as List<String>?)?.map((t) => t.toLowerCase()).join(' ') ?? '';

      return title.contains(query) || description.contains(query) || category.contains(query) || creator.contains(query) || tags.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Search', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          // Search Bar
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF000000)),
                decoration: InputDecoration(
                  hintText: 'Search videos, creators, categories...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF404040)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF404040)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF404040)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          // Show message if no results found
          if (_searchQuery.isNotEmpty && _filteredPosts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 80, color: AppColors.primaryGray.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text('No videos found', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
                    const SizedBox(height: 8),
                    Text('Try different keywords', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                  ],
                ),
              ),
            )
          else
            // Main grid of all posts
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1.0, // Square grid items
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  return GestureDetector(onTap: () => widget.onPostTap(_filteredPosts[index]), child: widget.buildExploreGridItem(_filteredPosts[index]));
                }, childCount: _filteredPosts.length),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
