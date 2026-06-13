import 'wiki_model.dart';
import 'wiki_comment_model.dart';
import 'dart:io';

abstract class WikiRepository {
  Future<List<WikiPage>> getCommunityWikis(String communityId);
  Future<void> createWiki(WikiPage wiki, {File? iconFile, File? coverFile});
  Future<void> deleteWiki(String wikiId);
  Future<List<WikiPage>> getUserWikis(String userId, {String? communityId});
  Future<void> updateWiki(WikiPage wiki, {File? iconFile, File? coverFile});
  Future<void> likeWiki(String wikiId, String userId);
  Future<void> unlikeWiki(String wikiId, String userId);
  Future<bool> checkIfLiked(String wikiId, String userId);
  Future<void> addWikiComment(String wikiId, WikiComment comment);
  Future<void> addWikiReply(String wikiId, String commentId, WikiComment reply);
  Future<List<WikiComment>> getWikiComments(String wikiId);
  Future<void> deleteWikiComment(String wikiId, String commentId);
  Future<void> deleteWikiReply(String wikiId, String commentId, WikiComment reply);
  Future<void> updateWikiComment(String wikiId, WikiComment comment);
  Future<WikiPage> getWiki(String wikiId);
  Future<List<WikiPage>> getPendingSubmissions(String communityId);
  Future<void> approveWiki(String wikiId);
  Future<void> submitToCatalog(String wikiId);
  Future<void> reactToWikiComment(String wikiId, String commentId, String userId, String reaction);
}
