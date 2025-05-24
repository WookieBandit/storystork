/*
lib/library_screen.dart - v1.8.10
- Implements Card UI for story lists (All My Stories & My Favorites).
- Includes filters for Age Range and Lesson (for "All My Stories" view).
- Includes sort options ("Newest", "Most Upvoted") for "All My Stories" view.
- Displays favorite status (star icon) on cards.
- Handles navigation to ContentDetailScreen, passing all necessary data.
- Includes logic for deleting stories and removing favorites.
- Addresses previous "unused element" and "padding" errors by ensuring
  all methods are correctly called and UI elements are properly structured.
*/
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'content_detail_screen.dart'; 
import 'lesson_examples.dart'; 

const List<String> _availableFilterAgeRanges = ['All', 'Not Specified', '1-3 years', '3-5 years', '5-7 years', '7-10 years', '10+ years'];
final List<String> _availableFilterLessons = ['All', ...lessonExamples.keys];

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  String _selectedFilterAgeRange = 'All';
  String _selectedFilterLesson = 'All'; 
  Stream<QuerySnapshot>? _libraryContentStream;
  bool _showOnlyFavorites = false; 
  String _currentLibrarySortOrder = 'newest'; 
  final List<Map<String, String>> _librarySortOptions = [
    {'value': 'newest', 'display': 'Newest'},
    {'value': 'most_upvoted', 'display': 'Most Upvoted'},
  ];

  Set<String> _favoritedContentIds = {};
  bool _isLoadingUserFavoritesSet = true;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _applyFiltersOrViewMode(); 
      _loadUserFavoriteIds(); 
    } else {
      _libraryContentStream = Stream.empty(); 
      if (mounted) setState(() => _isLoadingUserFavoritesSet = false);
    }
  }

  Future<void> _loadUserFavoriteIds() async { 
    if (_currentUser == null) { 
      if (mounted) setState(() => _isLoadingUserFavoritesSet = false); 
      return; 
    }
    if (!mounted) return;
    setState(() => _isLoadingUserFavoritesSet = true);
    try {
      QuerySnapshot snapshot = await _firestore.collection('user_favorites').where('userId', isEqualTo: _currentUser!.uid).get();
      final Set<String> ids = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('contentId')) { ids.add(data['contentId'] as String); }
      }
      if (mounted) { setState(() { _favoritedContentIds = ids; _isLoadingUserFavoritesSet = false; });}
    } catch (e) { 
      print("Error loading user favorite IDs for LibraryScreen: $e"); 
      if (mounted) { setState(() => _isLoadingUserFavoritesSet = false);}
    }
  }

  Query _buildFirestoreQuery() {
    if (_currentUser == null) { 
      return _firestore.collection('content').where('userId', isEqualTo: 'USER_MUST_BE_LOGGED_IN_INVALID_QUERY'); 
    }
    if (_showOnlyFavorites) { 
      return _firestore.collection('user_favorites').where('userId', isEqualTo: _currentUser!.uid).orderBy('favoritedAt', descending: true);
    } else { 
      Query query = _firestore.collection('content').where('userId', isEqualTo: _currentUser!.uid); 
      if (_selectedFilterAgeRange != 'All') { 
        query = query.where('selected_age_range', isEqualTo: _selectedFilterAgeRange == 'Not Specified' ? 'Not Specified' : _selectedFilterAgeRange); 
      } 
      if (_selectedFilterLesson != 'All') { 
        query = query.where('selected_lessons', arrayContains: _selectedFilterLesson); 
      } 
      if (_currentLibrarySortOrder == 'most_upvoted') {
        query = query.orderBy('upvoteCount', descending: true).orderBy('created_at', descending: true);
      } else { 
        query = query.orderBy('created_at', descending: true); 
      }
      return query; 
    }
  }

  void _applyFiltersOrViewMode() { 
    if (_currentUser == null && mounted) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in.'))); 
      setState(() => _libraryContentStream = Stream.empty()); 
      return; 
    }
    if(mounted) { 
      setState(() { _libraryContentStream = _buildFirestoreQuery().snapshots(); });
    }
  }

  void _clearFilters() {
     if (_currentUser == null && mounted) { 
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in.'))); 
       setState(() { 
         _selectedFilterAgeRange = 'All'; 
         _selectedFilterLesson = 'All'; 
         _currentLibrarySortOrder = 'newest'; 
         _libraryContentStream = Stream.empty(); 
        }); 
       return; 
      }
     if(mounted) { 
      setState(() {
        _selectedFilterAgeRange = 'All';
        _selectedFilterLesson = 'All';
        _currentLibrarySortOrder = 'newest'; 
        _libraryContentStream = _buildFirestoreQuery().snapshots(); 
      });
    }
  }

  Future<void> _confirmDeleteContent(BuildContext context, String docId, String displayTitle) async { 
    _showConfirmationDialog(
      context: context, 
      title: 'Delete Story', 
      content: 'Are you sure you want to delete "$displayTitle" from your generated stories? This action cannot be undone.', 
      onConfirm: () async => await _deleteContentFromLibrary(docId, displayTitle),
    );
  }
  
  Future<void> _deleteContentFromLibrary(String docId, String displayTitle) async { 
    if (_currentUser == null) { if (mounted) {ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Not logged in.')));} return;}
    try { 
      await _firestore.collection('content').doc(docId).delete(); 
      print('Content "$displayTitle" (ID: $docId) deleted successfully.'); 
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$displayTitle" deleted successfully!')));
      }
    } catch (e) { 
      print('Error deleting content "$displayTitle" (ID: $docId): $e'); 
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting "$displayTitle": ${e.toString()}')));
      }
    }
  }

  Future<void> _confirmUnfavorite(BuildContext context, String favoriteDocId, String displayTitle) async { 
     _showConfirmationDialog( 
       context: context, 
       title: 'Remove Favorite', 
       content: 'Are you sure you want to remove "$displayTitle" from your favorites?', 
       onConfirm: () async => await _removeFavorite(favoriteDocId, displayTitle),
      );
  }

  Future<void> _removeFavorite(String favoriteDocId, String displayTitle) async { 
    if (_currentUser == null) { if (mounted) {ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Not logged in.')));} return;}
    try { 
      await _firestore.collection('user_favorites').doc(favoriteDocId).delete(); 
      print('Favorite "$displayTitle" (Favorite ID: $favoriteDocId) removed successfully.'); 
      if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('"$displayTitle" removed from favorites!')),);
      }
    } catch (e) { 
      print('Error removing favorite "$displayTitle" (Favorite ID: $favoriteDocId): $e'); 
      if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Error removing favorite: ${e.toString()}')),);
      }
    }
    if (mounted) { 
      _loadUserFavoriteIds(); /* Refresh the set of favorite IDs to update stars everywhere */
      /* If currently showing favorites, the stream will rebuild. If showing all stories, this updates star icons */
    }
  }

  Future<void> _showConfirmationDialog({ 
    required BuildContext context, 
    required String title, 
    required String content, 
    required VoidCallback onConfirm,
  }) async { 
    return showDialog<void>(
      context: context, 
      barrierDismissible: false, 
      builder: (BuildContext dialogContext) { 
        return AlertDialog( 
          title: Text(title), 
          content: SingleChildScrollView(child: Text(content)), 
          actions: <Widget>[ 
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop()), 
            TextButton(child: Text(title.startsWith("Delete") ? 'Delete' : 'Confirm', style: TextStyle(color: title.startsWith("Delete") ? Colors.red : Theme.of(context).primaryColor)), onPressed: () { Navigator.of(dialogContext).pop(); onConfirm(); }),
          ],
        );
      },
    );
  }

  Future<void> _navigateToDetailScreen(Map<String, dynamic> data, String docId, bool isFromFavoritesCollection) async { 
    if (_currentUser == null || !mounted) return;
    Map<String, dynamic> contentDetailData; String actualContentId;
    if (isFromFavoritesCollection) {
      actualContentId = data['contentId'] as String? ?? ''; 
      if (actualContentId.isEmpty) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Content ID missing in favorite.'))); return; }
      try { 
        DocumentSnapshot contentDoc = await _firestore.collection('content').doc(actualContentId).get();
        if (contentDoc.exists && contentDoc.data() != null) { 
          contentDetailData = contentDoc.data() as Map<String, dynamic>; 
          contentDetailData['documentId'] = contentDoc.id; // Ensure docId is present from content
        } else { 
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Could not load full story details.'))); return; 
        }
      } catch (e) { 
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading story: ${e.toString()}'))); return; 
      }
    } else { 
      actualContentId = docId; 
      contentDetailData = Map<String, dynamic>.from(data); // Create a mutable copy
      contentDetailData['documentId'] = docId; // Ensure docId is present
    }
    if (!mounted) return;
    
    await Navigator.push( context, MaterialPageRoute( builder: (context) => ContentDetailScreen( 
      documentId: actualContentId, 
      title: contentDetailData['type'] as String? ?? 'Content', 
      storyTitle: contentDetailData['storyTitle'] as String?, 
      synopsis: contentDetailData['synopsis'] as String?,
      fullText: contentDetailData['fullText'] as String? ?? 'Full content not available.', 
      selectedThemes: List<String>.from(contentDetailData['selected_themes'] as List? ?? []), 
      selectedCharacters: List<String>.from(contentDetailData['selected_characters'] as List? ?? []), 
      selectedPersona: contentDetailData['selected_persona'] as String?, 
      selectedLength: contentDetailData['selected_length'] as String? ?? 'Medium', 
      initialIsPublic: contentDetailData['isPublic'] as bool? ?? false, 
      ownerUserId: contentDetailData['userId'] as String? ?? (_currentUser?.uid ?? ''), 
      currentUserId: _currentUser?.uid,
      selectedAgeRange: contentDetailData['selected_age_range'] as String?, 
      selectedLessons: List<String>.from(contentDetailData['selected_lessons'] as List? ?? [])
    ),),);
    if (mounted) { _loadUserFavoriteIds(); }
  }

  Widget _buildLibraryStoryCard(
    BuildContext context, 
    Map<String, dynamic> data, 
    String docIdForActions, 
    bool isFavoritedView,
    bool isActuallyFavoritedByCurrentUser 
  ) {
    String? storyTitle, contentType, synopsisText;
    String contentIdToUseForNavigation; 
    List<String> lessonsFromDoc = []; 
    String ageRangeDisplay = '';
    int viewCount = 0;
    int upvoteCount = 0;

    if (isFavoritedView) { 
      storyTitle = data['storyTitle'] as String?;
      contentType = data['contentType'] as String?;
      synopsisText = data['synopsis'] as String?;
      contentIdToUseForNavigation = data['contentId'] as String? ?? '';
    } else { 
      storyTitle = data['storyTitle'] as String?;
      contentType = data['type'] as String?;
      synopsisText = data['synopsis'] as String?;
      contentIdToUseForNavigation = docIdForActions; 
      lessonsFromDoc = List<String>.from(data['selected_lessons'] as List? ?? []);
      String? ageRangeFromDoc = data['selected_age_range'] as String?;
      ageRangeDisplay = ageRangeFromDoc ?? '';
      if (ageRangeDisplay == 'Not Specified') ageRangeDisplay = '';
      viewCount = data['viewCount'] as int? ?? 0;
      upvoteCount = data['upvoteCount'] as int? ?? 0;
    }
    String displayTitle = storyTitle != null && storyTitle.isNotEmpty ? storyTitle : (contentType ?? 'Content');

    return Card(
      elevation: 3.0, margin: const EdgeInsets.all(4.0), clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: InkWell(
        onTap: () { _navigateToDetailScreen(data, docIdForActions, isFavoritedView); },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.grey[300], child: Center(child: Icon(Icons.image_search, size: 30, color: Colors.grey[500]))),
                  if (!isFavoritedView && ageRangeDisplay.isNotEmpty)
                    Positioned(top: 4, right: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.black.withAlpha(150), borderRadius: BorderRadius.circular(3),), child: Text(ageRangeDisplay, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),),),),
                  
                  if (_currentUser != null && contentIdToUseForNavigation.isNotEmpty)
                    Positioned(top: 4, left: 4, child: Icon(
                      isFavoritedView ? Icons.star : (isActuallyFavoritedByCurrentUser ? Icons.star : Icons.star_border), 
                      color: (isFavoritedView || isActuallyFavoritedByCurrentUser) ? Colors.amber : Colors.white.withAlpha(180), 
                      size: 20.0,),
                    ),

                  Positioned( 
                    bottom: 2, right: 2,
                    child: IconButton(
                      icon: Icon(isFavoritedView ? Icons.favorite_border : Icons.delete_outline, /* Changed Icons.favorite_outlined to favorite_border for consistency if filled star is above */ color: Colors.white.withAlpha(200), size: 20,),
                      padding: EdgeInsets.zero, visualDensity: VisualDensity.compact,
                      tooltip: isFavoritedView ? 'Remove from Favorites' : 'Delete Story',
                      onPressed: () {
                        if (isFavoritedView) { _confirmUnfavorite(context, docIdForActions, displayTitle); } 
                        else { _confirmDeleteContent(context, docIdForActions, displayTitle); }
                      },
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(displayTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis,),
                  if (synopsisText != null && synopsisText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(synopsisText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ],
                  if (!isFavoritedView) ...[ 
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.thumb_up_alt_outlined, size: 11, color: Colors.deepPurple[700]), const SizedBox(width: 1), Text('$upvoteCount', style: TextStyle(fontSize: 10, color: Colors.deepPurple[700])),
                        const SizedBox(width: 5),
                        Icon(Icons.visibility_outlined, size: 11, color: Colors.blueGrey[700]), const SizedBox(width: 1), Text('$viewCount', style: TextStyle(fontSize: 10, color: Colors.blueGrey[700])),
                      ],
                    ),
                    if (lessonsFromDoc.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Chip(label: Text(lessonsFromDoc.first, style: const TextStyle(fontSize: 9)), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0), backgroundColor: Colors.green[50],),
                    ]
                  ] else if (isFavoritedView) ... [ 
                      if (storyTitle != null && storyTitle.isNotEmpty && contentType != null && contentType.isNotEmpty && storyTitle != contentType)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(contentType, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                        ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) { return Scaffold(appBar: AppBar(title: const Text('My Library')), body: const Center(child: Text('Please log in to view your library.'))); }

    return Scaffold(
      appBar: AppBar( title: const Text('My Library'), centerTitle: true,),
      body: Column(
              children: [
                Padding( 
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0), child: ToggleButtons(isSelected: [_showOnlyFavorites == false, _showOnlyFavorites == true], onPressed: (int index) {if(mounted) { setState(() { _showOnlyFavorites = index == 1; _applyFiltersOrViewMode(); });}}, borderRadius: BorderRadius.circular(8.0), selectedBorderColor: Theme.of(context).primaryColor, selectedColor: Colors.white, fillColor: Theme.of(context).primaryColor, color: Theme.of(context).primaryColor, constraints: BoxConstraints(minHeight: 40.0, minWidth: (MediaQuery.of(context).size.width - 48) / 2), children: const <Widget>[Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Text('All My Stories')), Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Text('My Favorites'))],),
                ),
                if (!_showOnlyFavorites) Padding( 
                  padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 8.0), child: ExpansionTile(title: const Text('Filters & Sort', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)), tilePadding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 0), childrenPadding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0), initiallyExpanded: false, children: [ 
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [ 
                      Expanded(child: DropdownButtonFormField<String>(decoration: InputDecoration(labelText: 'Age', border: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0)), contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), isDense: true, labelStyle: const TextStyle(fontSize: 13),), value: _selectedFilterAgeRange, items: _availableFilterAgeRanges.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 13)))).toList(), onChanged: (String? newValue) {if(mounted) setState(() { _selectedFilterAgeRange = newValue ?? 'All'; });},)), 
                      const SizedBox(width: 4), 
                      Expanded(child: DropdownButtonFormField<String>(decoration: InputDecoration(labelText: 'Lesson', border: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0)), contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), isDense: true, labelStyle: const TextStyle(fontSize: 13),), value: _selectedFilterLesson, items: _availableFilterLessons.map((String lessonKey) => DropdownMenuItem<String>(value: lessonKey, child: Text(lessonKey, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(), onChanged: (String? newValue) {if(mounted) setState(() { _selectedFilterLesson = newValue ?? 'All'; });},)),
                    ],),
                    const SizedBox(height: 6), 
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'Sort by', border: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0)), contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), isDense: true,labelStyle: const TextStyle(fontSize: 13),), 
                      value: _currentLibrarySortOrder,
                      items: _librarySortOptions.map((Map<String, String> option) {
                        return DropdownMenuItem<String>(value: option['value'], child: Text(option['display']!, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null && mounted) { setState(() => _currentLibrarySortOrder = newValue); }
                      },
                    ),
                    const SizedBox(height: 8), 
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      ElevatedButton.icon(icon: const Icon(Icons.filter_list_alt, size: 18), label: const Text('Apply', style: TextStyle(fontSize: 13)), onPressed: _applyFiltersOrViewMode, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6))), 
                      OutlinedButton.icon(icon: const Icon(Icons.clear_all, size: 18), label: const Text('Clear Filters', style: TextStyle(fontSize: 13)), onPressed: _clearFilters, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), side: BorderSide(color: Theme.of(context).primaryColor ))), 
                    ],), 
                    const SizedBox(height: 2),
                  ],),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _libraryContentStream, 
                    builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      if (snapshot.hasError) { print('Error fetching library content: ${snapshot.error}'); return Center(child: Text('Something went wrong: ${snapshot.error}'));}
                      if (snapshot.connectionState == ConnectionState.waiting || _isLoadingUserFavoritesSet) { return const Center(child: CircularProgressIndicator());}
                      if (snapshot.data == null || snapshot.data!.docs.isEmpty) { return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text( _showOnlyFavorites ? 'You haven\'t favorited any stories yet.' : 'Your library is empty or no items match your filters.', textAlign: TextAlign.center),));}

                      return GridView.builder(
                        padding: const EdgeInsets.all(8.0),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, 
                          childAspectRatio: 2 / 3.2, 
                          mainAxisSpacing: 8.0,
                          crossAxisSpacing: 8.0,
                        ),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (BuildContext context, int index) {
                          DocumentSnapshot document = snapshot.data!.docs[index];
                          Map<String, dynamic> data = (document.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
                          String docIdForActions = document.id; 
                          String contentIdToUseForFavCheck = _showOnlyFavorites ? (data['contentId'] as String? ?? '') : docIdForActions;
                          bool isActuallyFavorited = _favoritedContentIds.contains(contentIdToUseForFavCheck);
                          
                          return _buildLibraryStoryCard(context, data, docIdForActions, _showOnlyFavorites, isActuallyFavorited);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}