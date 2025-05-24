// lib/public_browse_screen.dart - v1.4.5 (Card UI Fixes & Enhancements)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'content_detail_screen.dart'; 
import 'login_screen.dart';         
import 'lesson_examples.dart'; 

const List<String> _availableFilterAgeRanges = ['All', 'Not Specified', '1-3 years', '3-5 years', '5-7 years', '7-10 years', '10+ years'];
final List<String> _availableFilterLessons = ['All', ...lessonExamples.keys];

class PublicBrowseScreen extends StatefulWidget {
  const PublicBrowseScreen({super.key});

  @override
  State<PublicBrowseScreen> createState() => _PublicBrowseScreenState();
}

class _PublicBrowseScreenState extends State<PublicBrowseScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String _selectedFilterAgeRange = 'All';
  String _selectedFilterLesson = 'All'; 
  Stream<QuerySnapshot>? _publicContentStream;
  String _currentSortOrder = 'newest'; 

  final List<Map<String, String>> _sortOptions = [
    {'value': 'newest', 'display': 'Newest'},
    {'value': 'popular', 'display': 'Views'},
    {'value': 'most_upvoted', 'display': 'Upvotes'},
  ];

  // _tierPublicViewLimits is used in _handlePublicStoryTap
  final Map<String, int> _tierPublicViewLimits = const {
    'free': 7, 'premium': 50, 'unlimited': 1000000,
  };
  
  // _favoritedContentIds is used in the GridView.builder item
  Set<String> _favoritedContentIds = {};
  bool _isLoadingUserFavoritesSet = true;

  @override
  void initState() { 
    super.initState();
    _applyFilters(); 
    _loadUserFavoriteIds();
  }

  Future<void> _loadUserFavoriteIds() async { 
    if (_currentUser == null) { 
      if (mounted) setState(() => _isLoadingUserFavoritesSet = false); 
      return; 
    }
    if (!mounted) return;
    setState(() => _isLoadingUserFavoritesSet = true);
    try {
      QuerySnapshot snapshot = await _firestore.collection('user_favorites').where('userId', isEqualTo: _currentUser.uid).get();
      final Set<String> ids = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('contentId')) { ids.add(data['contentId'] as String); }
      }
      if (mounted) { setState(() { _favoritedContentIds = ids; _isLoadingUserFavoritesSet = false; });}
    } catch (e) { print("Error loading user favorite IDs: $e"); if (mounted) { setState(() => _isLoadingUserFavoritesSet = false);}}
  }

  Query _buildFirestoreQuery() { 
    Query query = _firestore.collection('content').where('isPublic', isEqualTo: true);
    if (_selectedFilterAgeRange != 'All') {
      if (_selectedFilterAgeRange == 'Not Specified') { query = query.where('selected_age_range', isEqualTo: 'Not Specified');} 
      else { query = query.where('selected_age_range', isEqualTo: _selectedFilterAgeRange); }
    }
    if (_selectedFilterLesson != 'All') { query = query.where('selected_lessons', arrayContains: _selectedFilterLesson); }
    if (_currentSortOrder == 'popular') { query = query.orderBy('viewCount', descending: true).orderBy('created_at', descending: true); } 
    else if (_currentSortOrder == 'most_upvoted') { query = query.orderBy('upvoteCount', descending: true).orderBy('created_at', descending: true);}
    else { query = query.orderBy('created_at', descending: true); }
    return query;
  }

  void _applyFilters() { 
    setState(() { _publicContentStream = _buildFirestoreQuery().snapshots(); });
  }

  void _clearFilters() {
    setState(() { 
      _selectedFilterAgeRange = 'All'; 
      _selectedFilterLesson = 'All'; 
      _publicContentStream = _buildFirestoreQuery().snapshots(); 
    });
  }

  // This method IS used by _handlePublicStoryTap
  void _showInfoDialog(String title, String message) {
    if (!mounted) return; 
    showDialog(
      context: context, 
      builder: (BuildContext dialogContext) { 
        return AlertDialog(
          title: Text(title), 
          content: Text(message), 
          actions: <Widget>[TextButton(child: const Text('OK'), onPressed: () => Navigator.of(dialogContext).pop())],
        );
      }
    );
  }

  // This method IS called by the Card's onTap
  Future<void> _handlePublicStoryTap( Map<String, dynamic> storyData, String storyDocId) async {
    if (!mounted) return; 

    if (_currentUser == null) {
       showDialog(context: context, builder: (BuildContext dialogContext) { return AlertDialog(title: const Text('Login Required'), content: const Text('Please log in to view story details and use features like favorites or upvotes.'), actions: <Widget>[TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop()), TextButton(child: const Text('Login/Sign Up'), onPressed: () {Navigator.of(dialogContext).pop(); Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())); })],);});
      return;
    }

    DocumentReference userDocRef = _firestore.collection('users').doc(_currentUser.uid);
    String ownerUserId = storyData['userId'] as String? ?? '';
    String? storyTitleFromData = storyData['storyTitle'] as String?;
    String contentTypeFromData = storyData['type'] as String? ?? 'Content';
    String? synopsisFromData = storyData['synopsis'] as String?; 

    await Navigator.push( context, MaterialPageRoute( builder: (context) => ContentDetailScreen( documentId: storyDocId, title: contentTypeFromData, storyTitle: storyTitleFromData, synopsis: synopsisFromData, fullText: storyData['fullText'] as String? ?? 'Full content not available.', selectedThemes: List<String>.from(storyData['selected_themes'] as List? ?? []), selectedCharacters: List<String>.from(storyData['selected_characters'] as List? ?? []), selectedPersona: storyData['selected_persona'] as String?, selectedLength: storyData['selected_length'] as String? ?? 'Medium', initialIsPublic: storyData['isPublic'] as bool? ?? false, ownerUserId: ownerUserId, currentUserId: _currentUser.uid, selectedAgeRange: storyData['selected_age_range'] as String?, selectedLessons: List<String>.from(storyData['selected_lessons'] as List? ?? [])),),);
    
    if (mounted) { _loadUserFavoriteIds(); }

    if (_currentUser.uid == ownerUserId) {  
        print('Owner viewing their own story. No view limit/count logic applied here.');
        return; 
    }
    
    try {
      DocumentSnapshot userDocSnapshot = await userDocRef.get(); 
      if (!mounted) return; 
      Map<String, dynamic> userData = userDocSnapshot.data() as Map<String, dynamic>? ?? {};
      int storiesReadThisWeek = userData['publicStoriesReadThisWeek'] as int? ?? 0;
      Timestamp? lastResetTimestamp = userData['weeklyReadLimitLastReset'] as Timestamp?;
      DateTime lastResetDate = lastResetTimestamp?.toDate() ?? DateTime.now().subtract(const Duration(days: 8));
      DateTime now = DateTime.now(); bool wasReset = false;
      if (now.difference(lastResetDate).inDays >= 7) { storiesReadThisWeek = 0; wasReset = true; }
      String userTier = userData['currentTier'] as String? ?? 'free'; 
      int viewLimit = _tierPublicViewLimits[userTier] ?? _tierPublicViewLimits['free']!;
      if (storiesReadThisWeek < viewLimit) {
        Map<String, dynamic> updates = {};
        if (wasReset) { updates['publicStoriesReadThisWeek'] = 1; updates['weeklyReadLimitLastReset'] = FieldValue.serverTimestamp(); } 
        else { updates['publicStoriesReadThisWeek'] = FieldValue.increment(1); }
        await userDocRef.update(updates);
        print('Updated public story read count for user ${_currentUser.uid}');
      } else { 
        _showInfoDialog('Weekly Limit Reached', 'You have viewed your $viewLimit public stories for this week on your "$userTier" plan. Please try again later or consider upgrading for more access!');
      }
    } catch (e) { 
      print('Error handling public story view limit logic: $e'); 
    }
  }

  // Removed _buildStoryCard method as logic will be inlined in GridView.builder's itemBuilder

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Public Stories & Poems'), centerTitle: true,), 
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0), 
        child: ExpansionTile(
          title: const Text('Filters & Sort', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)), 
          tilePadding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 0), 
          childrenPadding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0), 
          initiallyExpanded: false, 
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center, 
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Age', border: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0)), contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), isDense: true, labelStyle: const TextStyle(fontSize: 13),), 
                    value: _selectedFilterAgeRange, 
                    items: _availableFilterAgeRanges.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value, style: TextStyle(fontSize: 13)))).toList(), // Removed const from TextStyle
                    onChanged: (String? newValue) => setState(() => _selectedFilterAgeRange = newValue ?? 'All'),
                  ),
                ),
                const SizedBox(width: 4), 
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Lesson', border: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0)), contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), isDense: true, labelStyle: const TextStyle(fontSize: 13),), 
                    value: _selectedFilterLesson, 
                    items: _availableFilterLessons.map((String lessonKey) => DropdownMenuItem<String>(value: lessonKey, child: Text(lessonKey, style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(), // Removed const from TextStyle
                    onChanged: (String? newValue) => setState(() => _selectedFilterLesson = newValue ?? 'All'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6), 
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Sort by', border: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0)), contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), isDense: true,labelStyle: const TextStyle(fontSize: 13),), 
              value: _currentSortOrder,
              items: _sortOptions.map((Map<String, String> option) => DropdownMenuItem<String>(value: option['value'], child: Text(option['display']!, style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(), // Removed const from TextStyle
              onChanged: (String? newValue) { if (newValue != null) { setState(() => _currentSortOrder = newValue); }},
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              ElevatedButton.icon(icon: const Icon(Icons.filter_list_alt, size: 18), label: const Text('Apply', style: TextStyle(fontSize: 13)), onPressed: _applyFilters, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6))), 
              OutlinedButton.icon(icon: const Icon(Icons.clear_all, size: 18), label: const Text('Clear Filters', style: TextStyle(fontSize: 13)), onPressed: _clearFilters, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), side: BorderSide(color: Theme.of(context).primaryColor ))), 
            ],),
             const SizedBox(height: 2), 
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: _publicContentStream,
          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.hasError) { print('Error fetching public content: ${snapshot.error}'); return Center(child: Text('Something went wrong: ${snapshot.error}')); }
            if (snapshot.connectionState == ConnectionState.waiting || _isLoadingUserFavoritesSet) { return const Center(child: CircularProgressIndicator()); }
            if (snapshot.data == null || snapshot.data!.docs.isEmpty) { return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No public content matches your current filters. Try adjusting or clearing them!', textAlign: TextAlign.center),));}

            return GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, 
                childAspectRatio: 2 / 3, // Adjusted for more vertical space
                mainAxisSpacing: 8.0,
                crossAxisSpacing: 8.0,
              ),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (BuildContext context, int index) {
                DocumentSnapshot document = snapshot.data!.docs[index];
                Map<String, dynamic> data = (document.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
                String docId = document.id;
                final bool isFavorited = _currentUser != null && _favoritedContentIds.contains(docId);
                
                String? storyTitle = data['storyTitle'] as String?;
                String contentType = data['type'] as String? ?? 'Content';
                String displayTitle = storyTitle != null && storyTitle.isNotEmpty ? storyTitle : contentType;
                String ageRangeDisplay = data['selected_age_range'] as String? ?? '';
                if (ageRangeDisplay == 'Not Specified') ageRangeDisplay = '';
                int viewCount = data['viewCount'] as int? ?? 0;
                int upvoteCount = data['upvoteCount'] as int? ?? 0;
                List<String> lessons = List<String>.from(data['selected_lessons'] as List? ?? []);


                return Card(
                  elevation: 3.0,
                  margin: const EdgeInsets.all(4.0), 
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)), 
                  child: InkWell(
                    onTap: () {
                      if (_currentUser != null) { 
                        _handlePublicStoryTap(data, docId);
                      } else { 
                        showDialog(context: context, builder: (BuildContext dialogContext) { return AlertDialog(title: const Text('View Full Story'), content: const Text('Please log in or create an account to view the full story and access more features.'), actions: <Widget>[ TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop()), TextButton(child: const Text('Login/Sign Up'), onPressed: () { Navigator.of(dialogContext).pop(); Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));},),],);},);
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch, // Make column stretch
                      children: [
                        Expanded( // Image placeholder takes available space
                          flex: 3, // Give more space to image
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(color: Colors.grey[300], child: Center(child: Icon(Icons.image_search, size: 30, color: Colors.grey[500]))), 
                              if (ageRangeDisplay.isNotEmpty)
                                Positioned(top: 4, right: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.black.withAlpha((0.6 * 255).round()), borderRadius: BorderRadius.circular(3),), child: Text(ageRangeDisplay, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),),),), 
                              if (_currentUser != null) 
                                Positioned(top: 4,left: 4, child: Icon(isFavorited ? Icons.star : Icons.star_border, color: isFavorited ? Colors.amber : Colors.white.withAlpha((0.7 * 255).round()), size: 20.0,),), 
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6.0), 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min, // So column doesn't try to expand infinitely
                            children: [
                              Text(displayTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis,), 
                              const SizedBox(height: 2), 
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Icon(Icons.thumb_up_alt_outlined, size: 11, color: Colors.deepPurple[700]), const SizedBox(width: 1), Text('$upvoteCount', style: TextStyle(fontSize: 10, color: Colors.deepPurple[700])),
                                  const SizedBox(width: 5),
                                  Icon(Icons.visibility_outlined, size: 11, color: Colors.blueGrey[700]), const SizedBox(width: 1), Text('$viewCount', style: TextStyle(fontSize: 10, color: Colors.blueGrey[700])),
                                ],
                              ),
                              if (lessons.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Chip(
                                  label: Text(lessons.first, style: const TextStyle(fontSize: 9)), // Display first lesson key
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, 
                                  visualDensity: VisualDensity.compact, 
                                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0), 
                                  backgroundColor: Colors.green[50],
                                ),
                              ]
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],),
    );
  }
}