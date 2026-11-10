import 'package:cloud_firestore/cloud_firestore.dart';

import 'cloud_repository.dart';
import 'models.dart';

const int firestoreSchemaVersion = 1;

DateTime? _timestampToDate(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

Object _createdAt(DateTime? value) =>
    value == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(value);

Map<String, dynamic> taskToFirestore(TaskItem task) => <String, dynamic>{
  'title': task.title,
  'categories': task.categories,
  'description': task.description,
  'deadline': task.deadline,
  'dueDate': task.dueDate == null ? null : Timestamp.fromDate(task.dueDate!),
  'done': task.done,
  'legacyId': task.legacyId,
  'schemaVersion': firestoreSchemaVersion,
  'createdAt': _createdAt(task.createdAt),
  'updatedAt': FieldValue.serverTimestamp(),
};

TaskItem taskFromFirestore(String id, Map<String, dynamic> data) {
  final List<String> categories =
      (data['categories'] as List<dynamic>?)
          ?.map((dynamic item) => item.toString())
          .toList() ??
      const <String>['Pribadi'];

  return TaskItem(
    id: id,
    legacyId: data['legacyId'] as String?,
    title: data['title'] as String? ?? '',
    categories: categories,
    description: data['description'] as String? ?? '',
    deadline: data['deadline'] as String? ?? '',
    dueDate: _timestampToDate(data['dueDate']),
    done: data['done'] as bool? ?? false,
    createdAt: _timestampToDate(data['createdAt']),
    updatedAt: _timestampToDate(data['updatedAt']),
  );
}

Map<String, dynamic> transactionToFirestore(TransactionItem transaction) =>
    <String, dynamic>{
      'label': transaction.label,
      'amount': transaction.amount,
      'cat': transaction.cat,
      'time': transaction.time,
      'date': transaction.date,
      'consumtive': transaction.consumtive,
      'receiptImagePath': transaction.receiptImagePath,
      'legacyId': transaction.legacyId,
      'schemaVersion': firestoreSchemaVersion,
      'createdAt': _createdAt(transaction.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };

TransactionItem transactionFromFirestore(
  String id,
  Map<String, dynamic> data,
) => TransactionItem(
  id: id,
  legacyId: data['legacyId'] as String?,
  label: data['label'] as String? ?? '',
  amount: (data['amount'] as num?)?.toInt() ?? 0,
  cat: data['cat'] as String? ?? 'other',
  time: data['time'] as String? ?? '00:00',
  date: data['date'] as String? ?? 'Hari ini',
  consumtive: data['consumtive'] as bool? ?? false,
  receiptImagePath: data['receiptImagePath'] as String?,
  createdAt: _timestampToDate(data['createdAt']),
  updatedAt: _timestampToDate(data['updatedAt']),
);

Map<String, dynamic> profileToFirestore(ProfileData profile) =>
    <String, dynamic>{
      ...profile.toJson(),
      'schemaVersion': firestoreSchemaVersion,
      'updatedAt': FieldValue.serverTimestamp(),
    };

class FirestoreCloudRepository implements CloudRepository {
  FirestoreCloudRepository({
    FirebaseFirestore? firestore,
    bool configurePersistence = true,
  }) : _firestore = firestore ?? FirebaseFirestore.instance {
    if (configurePersistence) {
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
  }

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userRef(String userId) =>
      _firestore.collection('users').doc(userId);

  CollectionReference<Map<String, dynamic>> _tasksRef(String userId) =>
      _userRef(userId).collection('tasks');

  CollectionReference<Map<String, dynamic>> _transactionsRef(String userId) =>
      _userRef(userId).collection('transactions');

  DocumentReference<Map<String, dynamic>> _profileRef(String userId) =>
      _userRef(userId).collection('profile').doc('main');

  DocumentReference<Map<String, dynamic>> _metaRef(String userId) =>
      _userRef(userId).collection('meta').doc('state');

  @override
  Stream<List<TaskItem>> watchTasks(String userId) =>
      _tasksRef(userId).snapshots().map(
        (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                  taskFromFirestore(doc.id, doc.data()),
            )
            .toList(),
      );

  @override
  Stream<List<TransactionItem>> watchTransactions(String userId) =>
      _transactionsRef(userId).snapshots().map(
        (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                  transactionFromFirestore(doc.id, doc.data()),
            )
            .toList(),
      );

  @override
  Stream<ProfileData?> watchProfile(String userId) =>
      _profileRef(userId).snapshots().map(
        (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
            snapshot.exists ? ProfileData.fromJson(snapshot.data()!) : null,
      );

  @override
  Stream<CloudMeta> watchMeta(String userId) => _metaRef(userId)
      .snapshots()
      .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
        final Map<String, dynamic>? data = snapshot.data();
        final Timestamp? updatedAt = data?['updatedAt'] as Timestamp?;
        return CloudMeta(
          lastSyncedAt: updatedAt?.toDate(),
          schemaVersion:
              (data?['schemaVersion'] as num?)?.toInt() ??
              firestoreSchemaVersion,
          hasPendingWrites: snapshot.metadata.hasPendingWrites,
        );
      });

  @override
  Future<bool> migrateLocalIfCloudEmpty(
    String userId, {
    required List<TaskItem> tasks,
    required List<TransactionItem> transactions,
    required ProfileData profile,
  }) {
    final DocumentReference<Map<String, dynamic>> metaRef = _metaRef(userId);
    final DocumentReference<Map<String, dynamic>> profileRef = _profileRef(
      userId,
    );
    return _firestore.runTransaction<bool>((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> meta = await transaction.get(
        metaRef,
      );
      final DocumentSnapshot<Map<String, dynamic>> remoteProfile =
          await transaction.get(profileRef);
      if (meta.exists || remoteProfile.exists) {
        return false;
      }

      for (final TaskItem task in tasks) {
        transaction.set(_tasksRef(userId).doc(task.id), taskToFirestore(task));
      }
      for (final TransactionItem item in transactions) {
        transaction.set(
          _transactionsRef(userId).doc(item.id),
          transactionToFirestore(item),
        );
      }
      if (profile.fullName.isNotEmpty ||
          profile.nim.isNotEmpty ||
          profile.program.isNotEmpty) {
        transaction.set(profileRef, profileToFirestore(profile));
      }
      transaction.set(metaRef, <String, dynamic>{
        'schemaVersion': firestoreSchemaVersion,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  @override
  Future<void> saveTask(String userId, TaskItem task) {
    final WriteBatch batch = _firestore.batch();
    batch.set(
      _tasksRef(userId).doc(task.id),
      taskToFirestore(task),
      SetOptions(merge: true),
    );
    _writeMeta(batch, userId);
    return batch.commit();
  }

  @override
  Future<void> deleteTask(String userId, String taskId) {
    final WriteBatch batch = _firestore.batch();
    batch.delete(_tasksRef(userId).doc(taskId));
    _writeMeta(batch, userId);
    return batch.commit();
  }

  @override
  Future<void> saveTransaction(String userId, TransactionItem transaction) {
    final WriteBatch batch = _firestore.batch();
    batch.set(
      _transactionsRef(userId).doc(transaction.id),
      transactionToFirestore(transaction),
      SetOptions(merge: true),
    );
    _writeMeta(batch, userId);
    return batch.commit();
  }

  @override
  Future<void> deleteTransaction(String userId, String transactionId) {
    final WriteBatch batch = _firestore.batch();
    batch.delete(_transactionsRef(userId).doc(transactionId));
    _writeMeta(batch, userId);
    return batch.commit();
  }

  @override
  Future<void> saveProfile(String userId, ProfileData profile) {
    final WriteBatch batch = _firestore.batch();
    batch.set(
      _profileRef(userId),
      profileToFirestore(profile),
      SetOptions(merge: true),
    );
    _writeMeta(batch, userId);
    return batch.commit();
  }

  @override
  Future<void> saveAll(
    String userId, {
    required List<TaskItem> tasks,
    required List<TransactionItem> transactions,
    required ProfileData profile,
  }) {
    final WriteBatch batch = _firestore.batch();
    for (final TaskItem task in tasks) {
      batch.set(
        _tasksRef(userId).doc(task.id),
        taskToFirestore(task),
        SetOptions(merge: true),
      );
    }
    for (final TransactionItem item in transactions) {
      batch.set(
        _transactionsRef(userId).doc(item.id),
        transactionToFirestore(item),
        SetOptions(merge: true),
      );
    }
    batch.set(
      _profileRef(userId),
      profileToFirestore(profile),
      SetOptions(merge: true),
    );
    _writeMeta(batch, userId);
    return batch.commit();
  }

  @override
  Future<void> deleteAllUserData(String userId) async {
    await _deleteCollection(_tasksRef(userId));
    await _deleteCollection(_transactionsRef(userId));
    await _deleteCollection(_userRef(userId).collection('profile'));
    await _deleteCollection(_userRef(userId).collection('settings'));
    await _deleteCollection(_userRef(userId).collection('meta'));
    final DocumentReference<Map<String, dynamic>> userRef = _userRef(userId);
    final DocumentSnapshot<Map<String, dynamic>> user = await userRef.get();
    if (user.exists) {
      await userRef.delete();
    }
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    const int pageSize = 400;
    while (true) {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await collection
          .limit(pageSize)
          .get();
      if (snapshot.docs.isEmpty) {
        return;
      }
      final WriteBatch batch = _firestore.batch();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < pageSize) {
        return;
      }
    }
  }

  void _writeMeta(WriteBatch batch, String userId) {
    batch.set(_metaRef(userId), <String, dynamic>{
      'schemaVersion': firestoreSchemaVersion,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
