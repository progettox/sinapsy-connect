import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_client_provider.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/campaign_model.dart';

final brandCampaignsControllerProvider =
    StateNotifierProvider<BrandCampaignsController, BrandCampaignsState>((ref) {
      return BrandCampaignsController(
        client: ref.watch(supabaseClientProvider),
        authRepository: ref.watch(authRepositoryProvider),
      );
    });

final createCampaignControllerProvider =
    StateNotifierProvider<CreateCampaignController, CreateCampaignState>((ref) {
      return CreateCampaignController(
        client: ref.watch(supabaseClientProvider),
        authRepository: ref.watch(authRepositoryProvider),
      );
    });

class BrandCampaignsState {
  const BrandCampaignsState({
    this.isLoading = false,
    this.errorMessage,
    this.campaigns = const <CampaignModel>[],
  });

  final bool isLoading;
  final String? errorMessage;
  final List<CampaignModel> campaigns;

  BrandCampaignsState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    List<CampaignModel>? campaigns,
  }) {
    return BrandCampaignsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      campaigns: campaigns ?? this.campaigns,
    );
  }
}

class CreateCampaignState {
  const CreateCampaignState({
    this.isSubmitting = false,
    this.errorMessage,
    this.lastCreatedCampaignId,
  });

  final bool isSubmitting;
  final String? errorMessage;
  final String? lastCreatedCampaignId;

  CreateCampaignState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    String? lastCreatedCampaignId,
    bool clearCreatedCampaign = false,
  }) {
    return CreateCampaignState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastCreatedCampaignId: clearCreatedCampaign
          ? null
          : (lastCreatedCampaignId ?? this.lastCreatedCampaignId),
    );
  }
}

class CreateCampaignInput {
  const CreateCampaignInput({
    required this.title,
    required this.description,
    required this.category,
    required this.cashOffer,
    required this.locationRequired,
    this.productBenefit,
    this.deadline,
    this.minFollowers,
    this.coverImageUrl,
  });

  final String title;
  final String description;
  final String category;
  final num cashOffer;
  final String? productBenefit;
  final DateTime? deadline;
  final int? minFollowers;
  final String locationRequired;
  final String? coverImageUrl;
}

class BrandCampaignsController extends StateNotifier<BrandCampaignsState> {
  BrandCampaignsController({
    required SupabaseClient client,
    required AuthRepository authRepository,
  }) : _client = client,
       _authRepository = authRepository,
       super(const BrandCampaignsState());

  final SupabaseClient _client;
  final AuthRepository _authRepository;

  Future<void> loadMyCampaigns() async {
    final brandId = _authRepository.currentUser?.id;
    if (brandId == null) {
      state = state.copyWith(errorMessage: 'Sessione non valida.');
      return;
    }

    _log('brand_campaigns.fetch.start brandId=$brandId');
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final rows = await _client
          .from('campaigns')
          .select()
          .eq('brand_id', brandId)
          .inFilter('status', const ['active', 'matched', 'completed'])
          .order('created_at', ascending: false);

      state = state.copyWith(
        isLoading: false,
        campaigns: _toCampaigns(rows),
        clearError: true,
      );
      _log(
        'brand_campaigns.fetch.success brandId=$brandId count=${state.campaigns.length}',
      );
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) {
        _log(
          'brand_campaigns.fetch.error brandId=$brandId code=${error.code} msg=${error.message}',
        );
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Errore caricamento campagne: ${error.message}',
        );
        return;
      }

      try {
        final rows = await _client
            .from('campaigns')
            .select()
            .eq('brandId', brandId)
            .inFilter('status', const ['active', 'matched', 'completed'])
            .order('createdAt', ascending: false);

        state = state.copyWith(
          isLoading: false,
          campaigns: _toCampaigns(rows),
          clearError: true,
        );
        _log(
          'brand_campaigns.fetch.fallback_success brandId=$brandId count=${state.campaigns.length}',
        );
      } catch (e) {
        _log('brand_campaigns.fetch.fallback_error brandId=$brandId error=$e');
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Errore caricamento campagne: $e',
        );
      }
    } catch (error) {
      _log('brand_campaigns.fetch.error brandId=$brandId error=$error');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Errore caricamento campagne: $error',
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  List<CampaignModel> _toCampaigns(dynamic rows) {
    final list = rows is List ? rows : const <dynamic>[];
    return list
        .whereType<Object>()
        .map(_toMap)
        .map(CampaignModel.fromMap)
        .where((campaign) => campaign.id.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _toMap(Object row) {
    if (row is Map<String, dynamic>) return row;
    if (row is Map) {
      return row.map((key, value) => MapEntry('$key', value));
    }
    throw StateError('Formato campaign non valido.');
  }

  bool _isColumnError(PostgrestException error) {
    return error.code == '42703' || error.code == 'PGRST204';
  }

  void _log(String message) {
    if (!kDebugMode) return;
    debugPrint('[BrandCampaignsController] $message');
  }
}

class CreateCampaignController extends StateNotifier<CreateCampaignState> {
  CreateCampaignController({
    required SupabaseClient client,
    required AuthRepository authRepository,
  }) : _client = client,
       _authRepository = authRepository,
       super(const CreateCampaignState());

  final SupabaseClient _client;
  final AuthRepository _authRepository;

  Future<String?> createCampaign(CreateCampaignInput input) async {
    final brandId = _authRepository.currentUser?.id;
    if (brandId == null) {
      state = state.copyWith(errorMessage: 'Sessione non valida.');
      return null;
    }

    if (input.title.trim().isEmpty ||
        input.description.trim().isEmpty ||
        input.category.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Compila tutti i campi obbligatori.',
      );
      return null;
    }
    if (input.cashOffer <= 0) {
      state = state.copyWith(
        errorMessage: 'Il budget deve essere maggiore di 0.',
      );
      return null;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearCreatedCampaign: true,
    );

    final now = DateTime.now().toUtc().toIso8601String();
    final canonicalPayload = <String, dynamic>{
      'brand_id': brandId,
      'title': input.title.trim(),
      'description': input.description.trim(),
      'category': input.category.trim(),
      'cash_offer': input.cashOffer,
      'product_benefit': _nullableString(input.productBenefit),
      'deadline': input.deadline?.toUtc().toIso8601String(),
      'min_followers': input.minFollowers,
      'location_required': _nullableString(input.locationRequired),
      'cover_image_url': _nullableString(input.coverImageUrl),
      'status': 'active',
      'applicants_count': 0,
      'created_at': now,
    };

    final payloadVariants = <Map<String, dynamic>>[
      canonicalPayload,
      <String, dynamic>{
        'brand_id': brandId,
        'title': input.title.trim(),
        'description': input.description.trim(),
        'category': input.category.trim(),
        'cash_offer': input.cashOffer,
        'product_benefit': _nullableString(input.productBenefit),
        'deadline': input.deadline?.toUtc().toIso8601String(),
        'min_followers': input.minFollowers,
        'location_required_city': _nullableString(input.locationRequired),
        'cover_image_url': _nullableString(input.coverImageUrl),
        'status': 'active',
        'applicants_count': 0,
        'created_at': now,
        'updated_at': now,
      },
      <String, dynamic>{
        'brandId': brandId,
        'title': input.title.trim(),
        'description': input.description.trim(),
        'category': input.category.trim(),
        'cashOffer': input.cashOffer,
        'productBenefit': _nullableString(input.productBenefit),
        'deadline': input.deadline?.toUtc().toIso8601String(),
        'minFollowers': input.minFollowers,
        'locationRequiredCity': _nullableString(input.locationRequired),
        'coverImageUrl': _nullableString(input.coverImageUrl),
        'status': 'active',
        'applicantsCount': 0,
        'createdAt': now,
      },
    ];

    _log(
      'campaign.insert.before brandId=$brandId title="${input.title.trim()}" category="${input.category.trim()}"',
    );

    PostgrestException? lastColumnError;
    for (final payload in payloadVariants) {
      try {
        final created = await _client
            .from('campaigns')
            .insert(payload)
            .select('id')
            .single();

        final id = (created['id'] ?? '').toString();
        state = state.copyWith(
          isSubmitting: false,
          lastCreatedCampaignId: id,
          clearError: true,
        );
        _log('campaign.insert.after success id=$id');
        return id;
      } on PostgrestException catch (error) {
        if (!_isColumnError(error)) {
          _log(
            'campaign.insert.after error code=${error.code} msg=${error.message}',
          );
          state = state.copyWith(
            isSubmitting: false,
            errorMessage: 'Errore creazione campagna: ${error.message}',
          );
          return null;
        }
        lastColumnError = error;
        _log(
          'campaign.insert.column_fallback code=${error.code} msg=${error.message}',
        );
      } catch (error) {
        _log('campaign.insert.after error=$error');
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'Errore creazione campagna: $error',
        );
        return null;
      }
    }

    state = state.copyWith(
      isSubmitting: false,
      errorMessage: 'Errore creazione campagna: ${lastColumnError?.message}',
    );
    return null;
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  bool _isColumnError(PostgrestException error) {
    return error.code == '42703' || error.code == 'PGRST204';
  }

  String? _nullableString(String? value) {
    final cleaned = (value ?? '').trim();
    if (cleaned.isEmpty) return null;
    return cleaned;
  }

  void _log(String message) {
    if (!kDebugMode) return;
    debugPrint('[CreateCampaignController] $message');
  }
}
