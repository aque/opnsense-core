{#
    # Copyright (c) 2024 Deciso B.V.
    # All rights reserved.
    #
    # Redistribution and use in source and binary forms, with or without modification,
    # are permitted provided that the following conditions are met:
    #
    # 1. Redistributions of source code must retain the above copyright notice,
    #    this list of conditions and the following disclaimer.
    #
    # 2. Redistributions in binary form must reproduce the above copyright notice,
    #    this list of conditions and the following disclaimer in the documentation
    #    and/or other materials provided with the distribution.
    #
    # THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
    # INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
    # AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    # AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
    # OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
    # SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
    # INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
    # CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
    # ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    # POSSIBILITY OF SUCH DAMAGE.
    #}

   <script>
       'use strict';

       $( document ).ready(function () {
           let grid_cert = $("#grid-cert").UIBootgrid({
               search:'/api/trust/cert/search/',
               get:'/api/trust/cert/get/',
               add:'/api/trust/cert/add/',
               set:'/api/trust/cert/set/',
               del:'/api/trust/cert/del/',
               options:{
                    requestHandler: function(request){
                        if ( $('#ca_filter').val().length > 0) {
                            request['carefs'] = $('#ca_filter').val();
                        }
                        return request;
                    }
                },
                commands: {
                    raw_dump: {
                        method: function(event){
                            let uuid = $(this).data("row-id") !== undefined ? $(this).data("row-id") : '';
                            ajaxGet('/api/trust/cert/raw_dump/' + uuid, {}, function(data, status){
                                if (data.stdout) {
                                    BootstrapDialog.show({
                                        title: "{{ lang._('Certificate info') }}",
                                        type:BootstrapDialog.TYPE_INFO,
                                        message: $("<div/>").text(data.stdout).html(),
                                        cssClass: 'monospace-dialog',
                                    });
                                }
                            });
                        },
                        classname: 'fa fa-fw fa-info-circle',
                        title: "{{ lang._('show certificate info') }}",
                        sequence: 10
                    }
                }
           });
           grid_cert.on("loaded.rs.jquery.bootgrid", function (e){
                // reload categories before grid load
                if ($("#ca_filter > option").length == 0) {
                    ajaxGet('/api/trust/cert/ca_list', {}, function(data, status){
                        if (data.rows !== undefined) {
                            for (let i=0; i < data.rows.length ; ++i) {
                                let row = data.rows[i];
                                $("#ca_filter").append($("<option/>").val(row.caref).html(row.descr));
                            }
                            $("#ca_filter").selectpicker('refresh');
                        }
                    });
                }
            });

            $("#filter_container").detach().prependTo('#grid-cert-header > .row > .actionBar > .actions');
            $("#ca_filter").change(function(){
                $('#grid-cert').bootgrid('reload');
            });

           /**
            * Autofill certificate fields when choosing a different CA
            */
           $("#cert\\.caref").change(function(event){
                if (event.originalEvent !== undefined) {
                    // not called on form open, only when the user chooses a new ca
                    ajaxGet('/api/trust/cert/ca_info/' + $(this).val(), {}, function(data, status){
                        if (data.name !== undefined) {
                            [
                                'city', 'state', 'country', 'name', 'email', 'organization', 'ocsp_uri'
                            ].forEach(function(field){
                                if (data[field]) {
                                    $("#cert\\." + field).val(data[field]);
                                }
                            });
                        }
                        $("#cert\\.country").selectpicker('refresh');
                    });
                }
           });

           $("#cert\\.action").change(function(event){
                if (event.originalEvent === undefined) {
                    // lock valid options based on server offered action
                    let visible_options = [$(this).val()];
                    if ($(this).val() == 'internal') {
                        visible_options.push('internal');
                        visible_options.push('external');
                        visible_options.push('import');
                    }
                    $("#cert\\.action option").each(function(){
                        if (visible_options.includes($(this).val())) {
                            $(this).attr('disabled', null);
                        } else {
                            $(this).attr('disabled', 'disabled');
                        }
                    });
                }

                let this_action = $(this).val();
                $(".action").each(function(){
                    let target = null;
                    if ($(this)[0].tagName == 'DIV') {
                        target = $(this)
                    } else {
                        target = $(this).closest("tr");
                    }
                    target.hide();
                    if ($(this).hasClass('action_' + this_action)) {
                        target.show();
                    }
                });
                /* expand/collapse PEM section */
                if (['import', 'import_csr'].includes($(this).val())) {
                    if ($(".pem_section >  table > tbody > tr:eq(0) > td:eq(0)").is(':hidden')) {
                        $(".pem_section >  table > thead").click();
                    }
                } else {
                    if (!$(".pem_section >  table > tbody > tr:eq(0) > td:eq(0)").is(':hidden')) {
                        $(".pem_section >  table > thead").click();
                    }
                }
            });
       });

   </script>

   <style>
        .monospace-dialog {
            font-family: monospace;
            white-space: pre;
        }

        .monospace-dialog > .modal-dialog {
            width:70% !important;
        }

        .modal-body {
            max-height: calc(100vh - 210px);
            overflow-y: auto;
        }
    </style>

   <ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
       <li class="active"><a data-toggle="tab" href="#cert">{{ lang._('Certificates') }}</a></li>
   </ul>
   <div class="tab-content content-box">
       <div id="cert" class="tab-pane fade in active">
            <div class="hidden">
                <!-- filter per type container -->
                <div id="filter_container" class="btn-group">
                    <select id="ca_filter"  data-title="{{ lang._('Authority') }}" class="selectpicker" data-live-search="true" data-size="5"  multiple data-width="200px">
                    </select>
                </div>
            </div>
            <table id="grid-cert" class="table table-condensed table-hover table-striped table-responsive" data-editDialog="DialogCert">
               <thead>
                   <tr>
                       <th data-column-id="uuid" data-type="string" data-identifier="true" data-visible="false">{{ lang._('ID') }}</th>
                       <th data-column-id="descr" data-width="15em" data-type="string">{{ lang._('Description') }}</th>
                       <th data-column-id="caref" data-width="15em" data-type="string">{{ lang._('Issuer') }}</th>
                       <th data-column-id="rfc3280_purpose" data-width="10em"  data-type="string">{{ lang._('Purpose') }}</th>
                       <th data-column-id="name" data-type="string">{{ lang._('Name') }}</th>
                       <th data-column-id="valid_from" data-width="10em" data-type="datetime">{{ lang._('Valid from') }}</th>
                       <th data-column-id="valid_to" data-width="10em" data-type="datetime">{{ lang._('Valid to') }}</th>
                       <th data-column-id="commands" data-width="9em" data-formatter="commands" data-sortable="false">{{ lang._('Commands') }}</th>
                   </tr>
               </thead>
               <tbody>
               </tbody>
               <tfoot>
                   <tr>
                       <td></td>
                       <td>
                           <button data-action="add" type="button" class="btn btn-xs btn-primary"><span class="fa fa-fw fa-plus"></span></button>
                           <button data-action="deleteSelected" type="button" class="btn btn-xs btn-default"><span class="fa fa-fw fa-trash-o"></span></button>
                       </td>
                   </tr>
               </tfoot>
             </table>
   </div>

   {{ partial("layout_partials/base_dialog",['fields':formDialogEditCert,'id':'DialogCert','label':lang._('Edit Certificate')])}}
