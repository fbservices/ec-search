<#ftl encoding="utf-8" />
<#import "/web/templates/modernui/funnelback_classic.ftl" as s/>
<#import "/web/templates/modernui/funnelback.ftl" as fb/>

<style type="text/css">
.fb_result_section b {
    font-weight: normal;
}
</style>

<div class="column_content">  
%globals_snippet_80508%

<input type="hidden" name="form" value="simple" />
</form>
<!-- RM: This is horrible! -->

<@s.AfterSearchOnly>
	<div class="fb_search_results">
    	<p class="fb_recommend"><@s.CheckSpelling></@s.CheckSpelling></p>

     	<!-- Result counts -->
     	<p class="fb_search_result_count">
     	<#if response.resultPacket.resultsSummary.totalMatching == 0>
     		There were <span>0</span> search results found.
     	</#if>
     	<#if response.resultPacket.resultsSummary.totalMatching != 0>
        	Showing 
            <span>${response.resultPacket.resultsSummary.currStart}</span> -
            <span>${response.resultPacket.resultsSummary.currEnd}</span> of
            <span>${response.resultPacket.resultsSummary.totalMatching?string.number}</span> search results.
     	</#if>
     	</p>

		<!-- RM: cluster breadcrumb logic goes here -->

</@s.AfterSearchOnly>
<br />
<ul class="fb_search_group_navigation">
	<li class="first group_current">
		<a href="%globals_asset_url%?collection=${question.collection.id}&form=simple">All results</a>
	</li>
    <li>
    	<a href="%globals_asset_url%?collection=${question.collection.id}&query=${question.query}&form=main-news-releases">News releases</a>
    </li>
    <li>
    	<a href="%globals_asset_url%?collection=${question.collection.id}&query=${question.query}&form=main-publications">Publications</a>
    </li>
    <li class="last">
    	<a href="%globals_asset_url%?collection=${question.collection.id}&query=${question.query}&form=main-cymraeg">Cymraeg</a>
    </li>
</ul>

<@s.AfterSearchOnly>

	<#if response.resultPacket.resultsSummary.totalMatching == 0>
		<div style="color:#484848; margin: 20px 0 50px 0"> <!-- RM: no inline styles please -->
    		<p>No results match your search.</p>
    		<p style="margin-top: 10px;">Suggestions:</p>
    		<ul style="margin: 10px 0 0 20px; list-style-type: disc;">
    			<li>check the spelling of your search</li>
    			<li>use fewer search terms</li>
    			<li>try different terms</li>
    		</ul>
		</div>
	</#if>
	<ul class="fb_search_result_list" id="fb_all_results">
		<@s.Results>
		<#if s.result.class.simpleName == "TierBar">
		<#else>
		<li>
			<#if s.result.fileType == 'pdf'>
				<h5 class="fb_doctype_pdf">			
			</#if>
			<#if s.result.fileType == 'doc'>
				<h5 class="fb_doctype_word">
			</#if>
			<#if s.result.fileType == 'xls'>
				<h5 class="fb_doctype_xls">
			</#if>
			<#if s.result.fileType == 'ppt'>
				<h5 class="fb_doctype_ppt">
			</#if>
			<#if s.result.fileType == 'jpg'>
				<h5 class="fb_doctype_image">
			</#if>
			<#if s.result.fileType == 'mp3'>
				<h5 class="fb_doctype_video">
			</#if>
			<#if s.result.fileType == 'mpg'>
				<h5 class="fb_doctype_video">
			</#if>
			<#if s.result.fileType == 'zip'>
				<h5 class="fb_doctype_zip">
			</#if>
			<#if s.result.fileType == 'html'>
				<h5>
			</#if>
			<a href="/search/${s.result.clickTrackingUrl}"
			   title="${s.result.liveUrl}">
				<@s.boldicize bold="${question.query}">${s.result.title}</@s.boldicize>
			</a>
			</h5>
			<!-- RM: Move eval logic to hook script if still needed -->
			<#if s.result.metaData.c?exists>
				<p>${s.result.metaData.c}</p>
			</#if>
			<#if s.result.fileType == 'html'>
				<#if s.result.metaData.A?exists>
					<div class="fb_result_section"><span>Section:</span> ${s.result.metaData.A}</div>
				</#if>
			</#if>
			<#if s.result.fileType != 'html' || s.result.fileType != 'cfm'>
				<div class="fb_result_section">
					<#if s.result.metaData.F?exists>
						<span>Type:</span> ${s.result.metaData.F}
						<span>File size:</span> 
						<#if s.result.metaData.E?exists>
							${s.result.metaData.E}
						<#else>
							${s.result.fileSize}
						</#if>
					</#if>
				</div>
			</#if>
			
			<#if s.result.date?exists>
				<div class="fb_result_date_published">${s.result.date?date}</div>
			</#if>
			<div class="fb_result_rate">
				<div class="rate_contents">
				<!-- RM: ec rate results plugin functionality here -->
				</div>
			</div>
		</li>
		</#if>
		</@s.Results>
	</ul>
</div>

<#if response.resultPacket.resultsSummary.totalMatching != 0>
	<div class="fb_search_pagination">
		<!-- ec pagination plugin goes here -->
	</div>
	<div class="fb_results_per_page">
        <span>Results per page:</span>
        <ul>
        <#if question.additionalParameters.num_ranks?exists && question.additionalParameters.num_ranks != 20>
            <li>10</li>
            <li class="page_divide">|</li>
      		<li><a href="%globals_asset_url%?collection=${question.collection.id}&form=${question.form}&query=${question.query}&num_ranks=20">20</a></li>
		<#else>
			<li><a href="%globals_asset_url%?collection=${question.collection.id}&form=${question.form}&query=${question.query}&num_ranks=10">10</a></li>
            <li class="page_divide">|</li>
            <li>20</li>
        </#if>
        </ul>
	</div>
</#if>
</@s.AfterSearchOnly>
</div> <!-- end column_content -->
<@s.AfterSearchOnly>
    <div class="column_tags">
        <div class="fb_widget most_popular">
            <h4>Most Popular</h4>
            <ul>
                <li><a href="http://www.electoralcommission.org.uk/party-finance/database-of-registers" title="Click here to search registered political parties and access party emblems."><span>></span>Registered parties</a></li>
                <li><a href="http://www.electoralcommission.org.uk/party-finance/database-of-registers" title="Click here to search for information about the finances of political parties and regulated donees."><span>></span>Finance of parties</a></li>
                <li><a href="http://www.aboutmyvote.co.uk" title="We don't hold copies of the electoral roll. Click here to go to our aboutmyvote site for more details of where to find the electoral roll and how to register to vote."><span>></span>Electoral roll</a></li>
            </ul>
        </div>
        <div class="fb_widget featured_items">
			<ul>
    			<@s.BestBets>
                    <#if s.bb.title?exists>
                    	<li>
                    		<a href="/search/${s.bb.clickTrackingUrl?html}">
                    			<span>></span>
                    			${s.bb.title}
                    		</a>
                    	</li>
                    </#if>
    			</@s.BestBets>
			</ul>
		</div>

	<@s.ContextualNavigation>
		<div class="fb_widget similiar_results">
	    	<h4>Similar results</h4>
			<@s.ClusterLayout>
				<@s.Category name="topic">
					<h5>Topics around <em>${s.contextualNavigation.searchTerm}</em></h5>
					<ul>
	                <@s.Clusters>
						<li><a href="${s.cluster.href}"><span>></span>${s.cluster.label}</a></li>
	                </@s.Clusters>
	                </ul>
	            </@s.Category>
				<@s.Category name="type">
					<h5>Different types of <em>${s.contextualNavigation.searchTerm}</em></h5>
					<ul>
	                <@s.Clusters>
	                	<li><a href="${s.cluster.href}"><span>></span>${s.cluster.label}</a></li>
	                </@s.Clusters>
	                </ul>
	            </@s.Category>
	       	</@s.ClusterLayout>
	
			<@s.NoClustersFound>
	        	<h5>No similar results</h5>
	        </@s.NoClustersFound>
		</div>
	</@s.ContextualNavigation>

	<div class="fb_widget related_forms">
		<h4>Related forms &amp; guidance</h4>
		<!-- RM: related results logic goes here -->
	</div>
</div>
</@s.AfterSearchOnly>

<!-- RM: this should be in a separate file -->
<script type="text/javascript" src="http://<s:env>BUREAU_ADDRESS</s:env>/search/electoral-commission/selectField.js"></script>
<script type="text/javascript">
setSelectMultiple('meta_s_phrase');
setSelectMultiple('meta_C');
setSelectMultiple('meta_D_or');
setSelectMultiple('meta_a_phrase');
setSelectMultiple('meta_f');
setSelectMultiple('meta_F_phrase');
setSelectMultiple('meta_d1day');
setSelectMultiple('meta_d1month');
setSelectMultiple('meta_d1year');
setSelectMultiple('meta_d2day');
setSelectMultiple('meta_d2month');
setSelectMultiple('meta_d2year');
setSelectMultiple('sort');
</script>