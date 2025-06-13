import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../settings.dart';
import '../auth/login.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  List<dynamic> _todos = [];
  bool _isLoading = true;
  String _userName = '';
  String _userEmail = '';
  
  // Animation controllers
  late AnimationController _headerAnimationController;
  late AnimationController _listAnimationController;
  late AnimationController _fabAnimationController;
  
  // Animations
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _headerFadeAnimation;
  late Animation<double> _listFadeAnimation;
  late Animation<double> _fabScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadUserData();
    _fetchTodos();
  }

  void _initAnimations() {
    _headerAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _listAnimationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fabAnimationController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    _headerSlideAnimation = Tween<double>(
      begin: -50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOut,
    ));

    _headerFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOut,
    ));

    _listFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _listAnimationController,
      curve: Curves.easeOut,
    ));

    _fabScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeOut,
    ));

    // Start animations
    _headerAnimationController.forward();
    Future.delayed(Duration(milliseconds: 200), () {
      _listAnimationController.forward();
    });
    Future.delayed(Duration(milliseconds: 400), () {
      _fabAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _listAnimationController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'User';
      _userEmail = prefs.getString('user_email') ?? '';
    });
  }

  Future<void> _fetchTodos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('$base_url/todos'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _todos = data['data'] ?? [];
        });
      } else {
        _showSnackBar('Failed to fetch todos', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Network error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(int todoId, String newStatus) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.patch(
        Uri.parse('$base_url/todos/$todoId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'status': newStatus,
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Status updated successfully', Colors.black);
        _fetchTodos();
      } else {
        _showSnackBar('Failed to update status', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Network error: $e', Colors.red);
    }
  }

  Future<void> _logout() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      await http.post(
        Uri.parse('$base_url/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      await prefs.clear();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } catch (e) {
      _showSnackBar('Logout error: $e', Colors.red);
    }
  }

  Future<void> _deleteTodo(int id) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.delete(
        Uri.parse('$base_url/todos/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _showSnackBar('Todo deleted successfully', Colors.black);
        _fetchTodos();
      } else {
        _showSnackBar('Failed to delete todo', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Network error: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.red ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color == Colors.red ? Colors.red : Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showDeleteDialog(int todoId, String title) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Delete Task',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$title"?',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteTodo(todoId);
              },
              child: Text(
                'Delete',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCompletedTaskDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Task Completed',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          content: Text(
            'This task is already completed and cannot be edited.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.black87;
      case 'pending':
        return Colors.grey[600]!;
      case 'in_progress':
        return Colors.grey[700]!;
      case 'late':
        return Colors.red;
      default:
        return Colors.grey[500]!;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'pending':
        return Icons.schedule;
      case 'in_progress':
        return Icons.timelapse;
      case 'late':
        return Icons.warning_outlined;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  Widget _buildAnimatedTaskCard(Map<String, dynamic> todo, int index) {
    final status = todo['status'].toString().toLowerCase();
    final isCompleted = status == 'completed';
    final isLate = status == 'late';
    
    return AnimatedBuilder(
      animation: _listAnimationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _listFadeAnimation.value)),
          child: Opacity(
            opacity: _listFadeAnimation.value,
            child: Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isLate ? Colors.red : Colors.grey[300]!,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {},
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Status Toggle
                        GestureDetector(
                          onTap: () {
                            if (status == 'pending' || status == 'late') {
                              _updateStatus(todo['id'], 'completed');
                            } else if (status == 'completed') {
                              _updateStatus(todo['id'], 'pending');
                            }
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isCompleted ? Colors.black87 : Colors.transparent,
                              border: Border.all(
                                color: isCompleted ? Colors.black87 : Colors.grey[400]!,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: isCompleted
                                ? Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        
                        SizedBox(width: 16),
                        
                        // Status Icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            _getStatusIcon(status),
                            color: _getStatusColor(status),
                            size: 20,
                          ),
                        ),
                        
                        SizedBox(width: 16),
                        
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              Text(
                                todo['title'] ?? 'No Title',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isCompleted ? Colors.grey[500] : Colors.black87,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                              
                              // Description
                              if (todo['description'] != null && todo['description'].isNotEmpty) ...[
                                SizedBox(height: 4),
                                Text(
                                  todo['description'],
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isCompleted ? Colors.grey[400] : Colors.grey[600],
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              
                              SizedBox(height: 8),
                              
                              // Status and Deadline Row
                              Row(
                                children: [
                                  // Deadline
                                  if (todo['deadline'] != null) ...[
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isLate ? Colors.red[50] : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isLate ? Colors.red[200]! : Colors.grey[300]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 12,
                                            color: isLate ? Colors.red : Colors.grey[600],
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            todo['deadline'] ?? 'No deadline',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isLate ? Colors.red : Colors.grey[600],
                                              decoration: isCompleted
                                                  ? TextDecoration.lineThrough
                                                  : TextDecoration.none,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                  ],
                                  
                                  // Status Badge
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isCompleted 
                                          ? Colors.black87 
                                          : isLate 
                                              ? Colors.red 
                                              : Colors.grey[700],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isCompleted
                                          ? 'DONE'
                                          : isLate
                                              ? 'LATE'
                                              : status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Action Menu
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            color: Colors.grey[600],
                            size: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          onSelected: (String value) {
                            if (value == 'edit') {
                              if (isCompleted) {
                                _showCompletedTaskDialog();
                              } else {
                                _showEditDialog(todo);
                              }
                            } else if (value == 'delete') {
                              _showDeleteDialog(todo['id'], todo['title']);
                            } else if (value == 'mark_completed') {
                              _updateStatus(todo['id'], 'completed');
                            } else if (value == 'mark_pending') {
                              _updateStatus(todo['id'], 'pending');
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            List<PopupMenuEntry<String>> menuItems = [];
                            
                            // Status change options
                            if (!isCompleted) {
                              menuItems.add(
                                PopupMenuItem<String>(
                                  value: 'mark_completed',
                                  child: Row(
                                    children: [
                                      Icon(Icons.check, size: 16, color: Colors.black87),
                                      SizedBox(width: 8),
                                      Text('Mark as Done', style: TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                              );
                            }
                            
                            if (isCompleted) {
                              menuItems.add(
                                PopupMenuItem<String>(
                                  value: 'mark_pending',
                                  child: Row(
                                    children: [
                                      Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                                      SizedBox(width: 8),
                                      Text('Mark as Pending', style: TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                              );
                            }
                            
                            // Edit option
                            menuItems.add(
                              PopupMenuItem<String>(
                                value: 'edit',
                                enabled: !isCompleted,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: isCompleted ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Edit',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isCompleted ? Colors.grey[400] : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            
                            // Delete option
                            menuItems.add(
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, size: 16, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text(
                                      'Delete',
                                      style: TextStyle(fontSize: 14, color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            
                            return menuItems;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Minimalist App Bar
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            flexibleSpace: AnimatedBuilder(
              animation: _headerAnimationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _headerSlideAnimation.value),
                  child: Opacity(
                    opacity: _headerFadeAnimation.value,
                    child: FlexibleSpaceBar(
                      background: Container(
                        color: Colors.white,
                        child: SafeArea(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // User Info
                                    Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Center(
                                            child: Text(
                                              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Hello,',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              _userName,
                                              style: TextStyle(
                                                color: Colors.black87,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    
                                    // Menu Button
                                    PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.more_vert,
                                        color: Colors.black87,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      onSelected: (String value) {
                                        if (value == 'logout') {
                                          _logout();
                                        }
                                      },
                                      itemBuilder: (BuildContext context) => [
                                        PopupMenuItem<String>(
                                          value: 'logout',
                                          child: Row(
                                            children: [
                                              Icon(Icons.logout, size: 16, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text(
                                                'Logout',
                                                style: TextStyle(color: Colors.red),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: 24),
                                
                                // Stats
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.task_alt,
                                        color: Colors.black87,
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Total Tasks',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              '${_todos.length}',
                                              style: TextStyle(
                                                color: Colors.black87,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Progress
                                      if (_todos.isNotEmpty) ...[
                                        Text(
                                          '${((_todos.where((todo) => todo['status'] == 'completed').length / _todos.length) * 100).round()}% done',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Todo List
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.all(16),
              child: _isLoading
                  ? Container(
                      height: 300,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Colors.black87,
                              strokeWidth: 2,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Loading tasks...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _todos.isEmpty
                      ? Container(
                          height: 300,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: Icon(
                                    Icons.task_outlined,
                                    size: 40,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No tasks yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Add your first task to get started',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchTodos,
                          color: Colors.black87,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section Header
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Text(
                                      'Tasks',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Spacer(),
                                    Text(
                                      '${_todos.length} items',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              SizedBox(height: 8),
                              
                              // Tasks List
                              // Tasks List
                              ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: _todos.length,
                                itemBuilder: (context, index) {
                                  return _buildAnimatedTaskCard(_todos[index], index);
                                },
                              ),
                            ],
                          ),
                        ),
            ),
          ),
        ],
      ),
      
      // Minimalist Floating Action Button
      floatingActionButton: AnimatedBuilder(
        animation: _fabAnimationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabScaleAnimation.value,
            child: FloatingActionButton(
              onPressed: () => _showAddDialog(),
              backgroundColor: Colors.black87,
              elevation: 4,
              child: Icon(
                Icons.add,
                color: Colors.white,
                size: 24,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddDialog() {
    _showTodoDialog();
  }

  void _showEditDialog(Map<String, dynamic> todo) {
    if (todo['status'].toString().toLowerCase() == 'completed') {
      _showCompletedTaskDialog();
      return;
    }
    _showTodoDialog(todo: todo);
  }

  void _showTodoDialog({Map<String, dynamic>? todo}) {
    final _titleController = TextEditingController(text: todo?['title'] ?? '');
    final _descriptionController = TextEditingController(text: todo?['description'] ?? '');
    final _deadlineController = TextEditingController(text: todo?['deadline'] ?? '');
    final _formKey = GlobalKey<FormState>();
    bool _isLoading = false;
    DateTime? _selectedDate;

    // Parse existing date if editing
    if (todo != null && todo['deadline'] != null) {
      try {
        _selectedDate = DateTime.parse(todo['deadline']);
      } catch (e) {
        _selectedDate = null;
      }
    }

    Future<void> _selectDate() async {
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);
      
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate ?? today,
        firstDate: today,
        lastDate: DateTime(2030),
        helpText: 'Select deadline',
        cancelText: 'Cancel',
        confirmText: 'OK',
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Colors.black87,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );

      if (picked != null) {
        setState(() {
          _selectedDate = picked;
          _deadlineController.text = DateFormat('yyyy-MM-dd').format(picked);
        });
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        todo == null ? 'Add Task' : 'Edit Task',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      
                      SizedBox(height: 4),
                      
                      Text(
                        todo == null 
                            ? 'Create a new task'
                            : 'Update task details',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      
                      SizedBox(height: 20),
                      
                      // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Title Field
                            TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: 'Title *',
                                labelStyle: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.black87, width: 2),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a title';
                                }
                                return null;
                              },
                            ),
                            
                            SizedBox(height: 16),

                            // Description Field
                            TextFormField(
                              controller: _descriptionController,
                              decoration: InputDecoration(
                                labelText: 'Description',
                                labelStyle: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.black87, width: 2),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              maxLines: 3,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            
                            SizedBox(height: 16),

                            // Deadline Field
                            TextFormField(
                              controller: _deadlineController,
                              decoration: InputDecoration(
                                labelText: 'Deadline *',
                                labelStyle: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.black87, width: 2),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    Icons.calendar_today,
                                    color: Colors.grey[600],
                                    size: 18,
                                  ),
                                  onPressed: _selectDate,
                                ),
                                hintText: 'Select date',
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                              readOnly: true,
                              onTap: _selectDate,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a deadline';
                                }
                                
                                try {
                                  final selectedDate = DateTime.parse(value);
                                  final today = DateTime.now();
                                  final todayOnly = DateTime(today.year, today.month, today.day);
                                  final selectedOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                                  
                                  if (selectedOnly.isBefore(todayOnly)) {
                                    return 'Deadline cannot be before today';
                                  }
                                } catch (e) {
                                  return 'Invalid date format';
                                }
                                
                                return null;
                              },
                            ),
                            
                            // Selected Date Info
                            if (_selectedDate != null) ...[
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Selected: ${DateFormat('EEE, MMM dd, yyyy').format(_selectedDate!)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 24),
                      
                      // Action Buttons
                      Row(
                        children: [
                          // Cancel Button
                          Expanded(
                            child: TextButton(
                              onPressed: _isLoading ? null : () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                          
                          SizedBox(width: 12),
                          
                          // Save Button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      if (_formKey.currentState!.validate()) {
                                        setState(() {
                                          _isLoading = true;
                                        });

                                        try {
                                          SharedPreferences prefs = await SharedPreferences.getInstance();
                                          String? token = prefs.getString('token');

                                          final url = todo == null
                                              ? '$base_url/todos'
                                              : '$base_url/todos/${todo['id']}';

                                          final method = todo == null ? 'POST' : 'PUT';

                                          final response = method == 'POST'
                                              ? await http.post(
                                                  Uri.parse(url),
                                                  headers: {
                                                    'Content-Type': 'application/json',
                                                    'Accept': 'application/json',
                                                    'Authorization': 'Bearer $token',
                                                  },
                                                  body: json.encode({
                                                    'title': _titleController.text.trim(),
                                                    'description': _descriptionController.text.trim(),
                                                    'deadline': _deadlineController.text,
                                                  }),
                                                )
                                              : await http.put(
                                                  Uri.parse(url),
                                                  headers: {
                                                    'Content-Type': 'application/json',
                                                    'Accept': 'application/json',
                                                    'Authorization': 'Bearer $token',
                                                  },
                                                  body: json.encode({
                                                    'title': _titleController.text.trim(),
                                                    'description': _descriptionController.text.trim(),
                                                    'deadline': _deadlineController.text,
                                                  }),
                                                );

                                          if (response.statusCode == 200) {
                                            Navigator.pop(context);
                                            _showSnackBar(
                                              todo == null ? 'Task added successfully' : 'Task updated successfully',
                                              Colors.black,
                                            );
                                            _fetchTodos();
                                          } else {
                                            final errorData = json.decode(response.body);
                                            _showSnackBar(
                                              errorData['message'] ?? 'Failed to save task',
                                              Colors.red,
                                            );
                                          }
                                        } catch (e) {
                                          _showSnackBar('Network error: $e', Colors.red);
                                        } finally {
                                          setState(() {
                                            _isLoading = false;
                                          });
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black87,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Saving...',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      todo == null ? 'Add Task' : 'Update Task',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
